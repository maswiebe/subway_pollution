/**********************************************
who_mortality.do

Created by sp, April 19 2017

**********************************************/

**MW: set location
cd "$gc_data/data_analysis/WHO_mortality/"

*set up
#delimit;
clear all;
set more 1;
set scheme s1mono;

*make empty temp directory;
shell rm -r temp; /* the /q /s part is a Windows command, equivalent to rm -rf */
mkdir temp;

*start log file;
/* quietly capture log close;
quietly log using who_mortality, text replace; */

*locations of source and generated data sets ;
global deathrates "../../data/WHO_mortality/source/WHO" ;
global relrisks "../../data/WHO_mortality/source/IER" ;
global generated "../../data/WHO_mortality/generated" ;
global data "../../data/merge/analyze_me.dta";

*step gates;
local step1 = 1 ;
local step2 = 1 ;
local step3 = 1 ;
local step4 = 1 ;

***************************************;
*  PROGRAM TO OMIT VARS FROM GLOBAL   *;
***************************************;
cap program drop takefromglobal;
program define takefromglobal;

	local original ${`1'};
	local temp1 `0';
	local temp2 `1';
	local except: list temp1 - temp2;
	local new: list original - except;
	global `1' `new';

end;

/*********************************************************
* STEP 1 : Calculate death rates from WHO spreadsheets   *
*********************************************************/

if `step1' ==1 {;

*create empty datasets to fill-up;
save temp/deathrates, emptyok replace;
save temp/population, emptyok replace;

foreach yr in "2000" "2005" "2010" "2015"
{;
	foreach age in "All ages" "0-4" "5-14" "15-29" "30-49" "50-59" "60-69" "70+"
	{;

		* import age and year specific death counts;
		import excel "${deathrates}/GHE2015_Deaths-`yr'-country.xls",
			sheet("Deaths `age'") cellrange(B8:GH214) firstrow clear;

		* keep only causes of death associated with PM2.5;
		keep if B == 1130 | B == 1140 | B == 680 | B == 1180 | B == 390;

		* clean and save;
		drop C D E ISO3Code;
		rename B causecode;
		rename F cause;
		gen year = `yr';
		gen age = "`age'";
		save temp/temp, replace;

		* append to master;
		use temp/deathrates, clear;
		append using temp/temp;
		save, replace;

		* import age and year specific population;
		import excel "${deathrates}/GHE2015_Deaths-`yr'-country.xls",
			sheet("Deaths `age'") cellrange(H8:GH10) firstrow clear;
		drop if _n==1;
		gen year = `yr';
		gen age = "`age'";
		save temp/temp, replace;

		* append to master;
		use temp/population, clear;
		append using temp/temp;
		save, replace;

	};
};

* reshape population and make merge-ready;
ds year age, not;
foreach variable in `r(varlist)'
{;
	rename `variable' ctry`variable';
};
reshape long ctry , i(year age) j(countrycode) s;
rename ctry pop;
replace age = "all" if age == "All ages";
bys countrycode year: egen popfr = max(pop);
replace popfr = pop/popfr;
save temp/population, replace;

* reshape death counts and make merge_ready;
use temp/deathrates, clear;
gen cause_accronym = "lri";
replace cause_accronym = "lung" if causecode == 390;
replace cause_accronym = "ihd" if causecode == 1130;
replace cause_accronym = "stroke" if causecode == 1140;
replace cause_accronym = "copd" if causecode == 1180;
drop causecode cause;
ds year age cause_accronym, not;
foreach variable in `r(varlist)'
{;
	rename `variable' ctry`variable';
};
reshape long ctry , i(year age cause_accronym) j(countrycode) s;
rename cause_accronym cause;
rename ctry deathrate_;
replace age = "all" if age == "All ages";
destring deathrate_, replace;
replace deathrate_ = 0 if deathrate_==.;
reshape wide deathrate_, i( countrycode year age) j(cause) s;

* merge, calculate death rates, and save copy in generated;
merge 1:1 year age countrycode using temp/population, nogen;
ds deathrate*;
foreach variable in `r(varlist)'
{;
	replace `variable' = `variable'/pop;
};
drop pop;
order countrycode year age, first;
save temp/deathrates, replace;
save ${generated}/UN_deathrates, replace;

};

/************************************************
* STEP 2 : Prepare and Organize Relative Risks  *
*************************************************/

if `step2' ==1 {;

clear;

* create empty datasets to fill-up;
set obs 126;
gen pm25 = _n-1;
save temp/relativerisk, replace;

* loop through csv files;
local files : dir "${relrisks}" files "rr_*.csv";
foreach file in `files' {;

	* string stubs;
	disp "`file'";
	local pos = strpos("`file'",".");
	disp "`pos'";
	local sub = substr("`file'",1,`pos'-1);
	disp "`sub'";

	*import and rename;
	import delimited "${relrisks}/`file'", clear;
	drop v1;
	rename risk `sub';
	rename lowerbound  `sub'_lb;
	rename upperbound  `sub'_ub;

	* linear interpolation for pm2.5 increments;
	ds rr*;
	foreach vari in `r(varlist)' {;
		gen `vari'_plus1 = `vari'[_n+1];
		replace `vari'_plus1=`vari' if `vari'_plus1==.;
	};
	expand 10 if _n!=_N,gen(c);
	bys pm25: gen cc = _n;
	replace cc = (cc-1)/10;
	replace pm25 = pm25 + cc;
	ds *plus* pm25 c cc, not;
	foreach vari in `r(varlist)' {;
		replace `vari' = cc*`vari'_plus + (1-cc)*`vari';
	};
	drop c cc *plus*;

	* save;
	save temp/temp, replace;

	* merge into master;
	use temp/relativerisk, clear;
	merge 1:1 pm25 using temp/temp, nogen;
	save, replace;

};

*save copy in generated;
save ${generated}/RelativeRisks, replace; 
* MW: this is just the list(1:125);
* above loop is not doing anything;

};

/************************************************
* STEP 3 : Subway cities PM2.5 at opening       *
*************************************************/

if `step3' ==1 {;

* prepare data and store estimates for \hat(PM2.5} ;
do aod2pm;

* re-load data;
use temp/main_data.dta, clear;

*keep desired product and setup for satellite reshape;
local stubs;
foreach stat in "mean" "count"
{;
	foreach ring in "10km" "25km" "50km" "150km"
	{;
		if "`stat'"=="mean" local stubs `stubs' aod_`stat'_`ring' log_aod_`stat'_`ring';
		if "`stat'"=="count" local stubs `stubs' aod_`stat'_`ring';
	};
};

* create USA gdp variable for VSL calculation in step4;
bys year month: gen gdp_temp = gdp if country == "United States";
bys year month: egen gdp_USA = max(gdp_temp);

*reshave and save again;
reshape long `stubs', i(urbancode date) j(satellite) s;
replace satellite = substr(satellite,2,.);

*****************************;
* Keep only High AOD cities *;
*****************************;
gen expansion_number =1 ;
bys urbancode expansion_number: egen mint = min(t);
bys urbancode expansion_number: egen maxt = max(t);

*gen dummy for obs. outside of the treatment window;
gen post_window = 0;
replace post_window = 1 if t > 18 & t != .;
replace t = 9999 if t > 18 & t != .;
gen pre_window = 0;
replace pre_window = 1 if t < -18 & t != .;
replace t = -9999 if t < -18 & t != .;

*Sample-specific restrictions;
gen sample_city = 1;
drop if date_start == .;
replace sample_city = 0 if  mint>-18;
replace sample_city = 0 if  maxt<18;
keep if sample_city == 1;

*gen dummy for top/bottom AOD in 2000;
bys urbancode: gen prewindow_aod = ${pre_}aod_mean_${ring} if year == 2000;
bys urbancode: egen mprewindow_aod = mean(prewindow_aod);
bys urbancode: gen nn = _n;
sum mprewindow_aod if nn==1 & sample_city == 1, d;
gen hiAOD = ( mprewindow_aod > r(p50) );
drop prewindow_aod mprewindow_aod nn;
keep if satellite == "Terra";
**MW: use full sample, instead of only high-pollution;
*keep if hiAOD == 1;
rename ${pre_}aod_mean_${ring} ${pre_}aod_mean_${ring}_Terra;
rename ${pre_}aod_count_${ring} ${pre_}aod_count_${ring}_Terra;

* keep 1 year before opening;
*bys urbancode: egen mint = min(t);
drop if mint>-13;
keep if t<0 & t>-13;
drop mint;

* adjust year for collapse;
gen tempyear = year if t==-1;
bys urbancode: egen yearop = max(tempyear);
replace year = yearop;

*collapse yearly to obtain predicted particulate;
collapse (mean)
${${pre_x_}C2_${ring}} aod_mean_${ring}_Terra ${${pre_x_}C4} gdp_USA
PM10_OAP2011 PM25_OAP2011 PM10_OAP2014 PM25_OAP2014 PM10_OAP2016 PM25_OAP2016
(sum) aod_count_${ring}_Terra, by(urbancode urbanname country continent year);
encode continent, gen(continent_n);
egen PM10 = rowmean(PM10_OAP2011 PM10_OAP2014 PM10_OAP2016);
egen PM25 = rowmean(PM25_OAP2011 PM25_OAP2014 PM25_OAP2016);

*calculate pre and post-opening predicted PM2.5;
predict pred_pm25_pre;
replace aod_mean_${ring}_Terra = aod_mean_${ring}_Terra - 0.028;
predict pred_pm25_post;

*clean and save;
replace pred_pm25_pre  = round(pred_pm25_pre,.1);
replace pred_pm25_pre  = 0 if pred_pm25_pre  < 0;
replace pred_pm25_post = round(pred_pm25_post,.1);
replace pred_pm25_post = 0 if pred_pm25_post  < 0;
keep urbanname urbancode country year city_pop gdp gdp_USA
     pred_pm25_pre pred_pm25_post;
gen year_og = year;
replace year = round(year,5);
save temp/cities_pm25, replace;

};

/*********************************
* STEP 4 : Burden of disease!    *
**********************************/

**MW: this code produces an error;
/* if `step4' ==1 {;

* get isocode3 key for merge;
import delimited "${deathrates}/iso3codes.txt", clear;
keep name alpha3;
rename alpha3 countrycode;
rename name country;
save temp/temp, replace;

* prepare relative risks for merge;
use temp/relativerisk, clear;
drop *_lb *_ub;
**MW: get error here: variable not found;
ds rr*;
foreach vari in `r(varlist)' {;
	gen `vari'_pre = `vari';
	gen `vari'_post = `vari';
	drop `vari';
};
gen pred_pm25_pre = pm25;
gen pred_pm25_post = pm25;
drop pm25;
save temp/relativerisk, replace;

* reshape deathrates again for merge;
use temp/deathrates, clear;
ds death* popfr;
foreach vari in `r(varlist)' {;
	rename `vari' `vari'_;
};
replace age = subinstr(age,"-","_",.);
replace age = subinstr(age,"+","plus",.);
reshape wide death* popfr, i(countrycode year) j(age) s;
save temp/deathrates, replace;

* merge everything into one dataset;
use temp/cities_pm25, clear;
recast str52 country, force;
merge m:1 country using temp/temp, nogen keep(matched);
merge m:1 countrycode year using temp/deathrates, nogen keep(matched);
merge m:1 pred_pm25_pre using temp/relativerisk, keepus(*_pre) nogen keep(matched);
merge m:1 pred_pm25_post using temp/relativerisk, keepus(*_post) nogen keep(matched);

* city-level deaths for each cause-by-age;
ds deathrate*;
foreach vari in `r(varlist)' {;
	local vari2 = substr("`vari'",10,.);
	gen deaths`vari2' = `vari'*city_pop*1000;
};

* fraction of deaths saved by subways for each cause-by-age (PAF);
ds rr_*_pre;
foreach vari in `r(varlist)' {;
	local vari2 = substr("`vari'",1,strpos("`vari'","pre")-1);
	local vari3 = substr("`vari'",3,strpos("`vari'","pre")-4);
	gen fr`vari3' = 1- (`vari2'post/`vari');
};

* make age groups for deaths and fraction deaths compatible;
foreach cause in  "ihd" "stroke" {;

	egen fr_`cause'_0_30  = rowmean(fr_`cause'_25 fr_`cause'_30);
	egen fr_`cause'_30_50 = rowmean(fr_`cause'_35 fr_`cause'_40 fr_`cause'_45 fr_`cause'_50);
	egen fr_`cause'_50_60 = rowmean(fr_`cause'_55 fr_`cause'_60);
	egen fr_`cause'_60_70 = rowmean(fr_`cause'_65 fr_`cause'_70);
	egen fr_`cause'_70_80 = rowmean(fr_`cause'_75 fr_`cause'_80);

	egen deaths_`cause'_0_30  = rowtotal(deaths_`cause'_0_4 deaths_`cause'_5_14 deaths_`cause'_15_29);
	egen deaths_`cause'_30_50 = rowtotal(deaths_`cause'_30_49);
	egen deaths_`cause'_50_60 = rowtotal(deaths_`cause'_50_59);
	egen deaths_`cause'_60_70 = rowtotal(deaths_`cause'_60_69);
	egen deaths_`cause'_70_80 = rowtotal(deaths_`cause'_70plus);

};

* calculate avoided deaths due to subway opening;
gen avoided_deaths_lung = fr_lung * deaths_lung_all;
gen avoided_deaths_copd = fr_copd * deaths_copd_all;
gen avoided_deaths_lri = fr_lri * deaths_lri_all;
foreach cause in  "ihd" "stroke"
{;
	foreach age in  "_0_30" "_30_50" "_50_60" "_60_70" "_70_80"
	{;
		gen avoided_deaths_`cause'`age' = fr_`cause'`age' * deaths_`cause'`age';
};
};
egen avoided_deaths = rowtotal(avoided_deaths*);

* consistency check: avoided deaths in 0-4 age;
gen avoided_deaths_0_4_lung = deaths_lung_0_4*fr_lung;
gen avoided_deaths_0_4_copd = deaths_copd_0_4*fr_copd;
gen avoided_deaths_0_4_lri = deaths_lri_0_4*fr_lri;
gen avoided_deaths_0_4_ihd = deaths_ihd_0_4*fr_ihd_25;
gen avoided_deaths_0_4_stroke = deaths_stroke_0_4*fr_stroke_25;
egen avoided_deaths_0_4 = rowtotal(avoided_deaths_0_4*);

* calculate country-specific VSL;
gen VSL = ((gdp/gdp_USA)^0.6)*6000000;

* calculate birthrate;
gen birthrate = popfr_0_4/5; 

* mortality estimate from econ lit;
gen avoided_deaths_0_1 = birthrate*(city_pop*1000)*2.9*(10/100000); 
gen avoided_deaths_0_1_dollars = (avoided_deaths_0_1*VSL)/1000000000;

*other calculations;
gen avoided_deaths_dollars = (avoided_deaths*VSL)/1000000000;

* clean & save;
keep year country urbanname urbancode city_pop pred_pm25_pre pred_pm25_post
     avoided_deaths avoided_deaths_0_4 avoided_deaths_0_1 avoided_deaths_dollars avoided_deaths_0_1_dollars
	 birthrate VSL;
save avoided_deaths, replace;

}; */

/**********************
* STEP 5 : The end    *
**********************/

*clean up;
/* log close; */
/* shell rm -r temp; */
exit;
