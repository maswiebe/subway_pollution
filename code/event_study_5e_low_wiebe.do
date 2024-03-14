**MW: my comments are denoted with '**MW'

**MW: set location
cd "$gc_data/data_analysis/dofiles/"

/**********************************************
event_study.do

Last updated October 28, 2020 by NGC

**********************************************/

#delimit;

*locations of directories;
cd ../../../;
pwd;
global root   "`c(pwd)'";
global home "${root}/data_proccessing/data_analysis";
cd $home;
cd output_event_study/tables;
global tables "`c(pwd)'";
cd ../figures;
global figures "`c(pwd)'";
cd $home;

*input dataset;
global data "${root}/data_proccessing/data/merge/analyze_me.dta";

*set up;
cd dofiles;
clear;
set more on;
set matsize 6000;
set more 1;
set scheme s1mono;
postutil clear;

*start log file;
/* quietly capture log close;
quietly log using event_study_5c.log, text replace; */

cd $home;

*make empty temp directory;
*shell rmdir temp /q /s;
shell rm -r 'temp';
mkdir temp;

**************************************;
*     WORKFLOW SETTINGS              *;
**************************************;

*Set = 1 to overwrite previous results (replaces whole output folder);
local overwrite = 0;

*Set = 1 to produce regression tables;
local gateTables = 1;

*Set the time for the reference group*;
*e.g. 6 months before the opening: global reftime = 6 *;
global reftime = 6;

*Set heteroeneity options;
*NOTE*: Use !=0 only with sample 1, 11, or 12 and when bin = window;
local hets = "0";
* -- 0: no heterogeneity;
* -- 1: interaction with Asia dummy;
* -- 2: interaction with poor cities dummy;
* -- 3: interaction with big opening;
* -- 4: interaction with large city;
* -- 5: interaction with big opening relative to city size;
* -- 6: interaction with rainy vs less rainy cities;
* -- 7: interaction with high vs low AOD in 2000;
* -- 8: interaction with fast-growing cities before opening;
* -- 9: interaction with post AEJ opening dummy;
* -- 10: interaction with high vs low AOD 18m before opening;
* -- 11: interaction with China dummy;
* -- 12: interaction with windy cities;
* -- 13: interaction with high altitude cities;
* -- 14: interaction with high elevation range cities;
* -- 15: interaction with dense cities;

*Set ridership option;
local rider = 0;

*Set samples for event analysis;
local samples = "6 62";
* -- s1: symmetric windows - constant sample;
* -- s11: symmetric windows - constant sample - include old subway cities;
* -- s12: symmetric windows - constant sample - include never subway cities;
* -- s2: asymmetric windows - short pre + long post - changing sample;
* -- s21: asymmetric windows - short pre + long post - changing sample - include old subway cities;
* -- s22: asymmetric windows - short pre + long post - changing sample - include never cities;
* -- s3: changing sample (symmetric and asymmetric windows);
* -- s6: asymmetric windows - short pre + long post - constant sample;
* -- s61: asymmetric windows - short pre + long post - constant sample - include old subway cities;
* -- s62: asymmetric windows - short pre + long post - constant sample - include never subway cities;

*Settings for line expansions;
global expandlines   = 0;

*Set restrictions for event analysis;
* -- r1: full sample;
* -- r2: weight obs by pixelcount;
* -- r3: drop low pixel count;
* -- r4: drop rainy months;
* -- r5: drop cityXsatelliteXmonth outliers;
local restrictions = "1";

*Set which radiuses to use for regs;
*-- add distances inside quotes;
local radlist = "10km"; // 10km 25km 50km 150km

*Set which climate controls to use for regs;
*-- add vars inside quotes;
****** CHEAT SHEET  ***********************************;
*cld   cloud cover, percentage (%);
*dtr   diurnal temperature range, degrees Celsius;
*frs   frost day frequency, days;
*pet   potential evapotranspiration, millimetres per day;
*pre   precipitation, millimetres per month;
*tmp   daily mean temp, deg Celsius;
*tmn   monthly avg daily minimum temp, deg Celsius;
*tmx   monthly avg daily maximum temp, deg Celsius;
*vap   vapour pressure, hectopascals (hPa);
*wet   wet day frequency, days;
*******************************************************;
local climlist = "tmp vap cld pre frs "; // tmp vap cld pre dtr tmn tmx frs pet wet

*error setting for regressions;
global error "cl(urbancode)";  // cluster at city level

*Specification Settings;
global XK "3K";   // SET = "3K" . Refers to AOD product.
local til2014 = 0; // SET = 1 to drop obs after Dec. 2013.
local  y_log = 0; // SET =1 FOR LOG AOD
local  x_log = 0; // SET =1 FOR LOG CNTRLS
local  x_sq  = 1; // SET =1 FOR SQUARE CNTRLS
local  x_cu  = 0; // SET =1 FOR CUBIC CNTRLS
global foot ""; // SET = "_foot" to use AOD measure calculated in city footprint.

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

***************************************;
*  PROGRAM TO COUNT NUMBER OF EVENTS  *;
***************************************;
cap program drop countevents;
program define countevents;
	** Note: To be used after regression to count
	** how many events were observable with all covariates;
	gen in_regression = (e(sample) ==1);

	if $expandlines == 0
	{;
		gen expansion_number =1 ;
	};

	bys in_regression sample_city urbancode expansion_number: gen nn = _n if in_regression ==1 & sample_city==1;
	count if nn==1 ;
	global Nevents = r(N);

	bys in_regression urbancode expansion_number: gen nn2 = _n if in_regression ==1;
	count if nn2==1 ;
	global Ncities = r(N);

	if $expandlines == 0
	{;
		drop expansion_number;
	};

	drop nn* in_regression;

end;

**************************************************;
*  PROGRAM TO EXPAND DATASET FOR LINE OPENINGS   *;
**************************************************;
cap program drop expand_lines;
program define expand_lines;

end;

***************************************;
*    WINDOW-SPECIFIC SETUP PROGRAM    *;
***************************************;
cap program drop windowsetup;
program define windowsetup;

	use "${home}/temp/main_data`3'.dta", clear;

	if `5' == 1
	{;
		expand_lines `4';
	};

	*gen satellite-specific intercept;
	cap gen satdum = (satellite == "Terra");

	*gen dummy for obs. belonging to city with event inside window;
	if $expandlines == 0 {;
	gen expansion_number =1 ;
	};

	bys urbancode expansion_number: egen mint = min(t);
	bys urbancode expansion_number: egen maxt = max(t);

	if $expandlines == 0 {;
	drop expansion_number;
	};

	replace t  = date-tm(2100m1) if date_start==.;
	replace t = date-date_start if date_start < tm(2000m2);

	*gen dummy for obs. outside of the treatment window;
	gen post_window = 0;
	replace post_window = 1 if t > `1' & t != .;
	replace t = 9999 if t > `1' & t != .;
	gen pre_window = 0;
	replace pre_window = 1 if t < -1*`4' & t != .;
	replace t = -9999 if t < -1*`4' & t != .;

	*Sample-specific restrictions;
	gen sample_city = 1;
	gen sample_city18 = 1;
	replace sample_city18 = 0 if  mint>-18;
	replace sample_city18 = 0 if  maxt<18;

	* -- s1: symmetric windows - constant sample;
	if `2' == 1
	{;
		drop if date_start == .;
		replace sample_city = 0 if  mint>-1*`4';
		replace sample_city = 0 if  maxt<`1';
		keep if sample_city == 1;
	};

	* -- s11: symmetric windows - constant sample - include old subway cities;
	if `2' == 11
	{;
		drop if date_start == .;
		replace sample_city = 0 if  mint>-1*`4';
		replace sample_city = 0 if  maxt<`1';
		keep if sample_city == 1 | date_start < tm(2000m2) ;
	};

	* -- s12: symmetric windows - constant sample - include old subway cities and all non-subway cities;
	if `2' == 12
	{;
		replace sample_city = 0 if  mint>-1*`4';
		replace sample_city = 0 if  maxt<`1';
		keep if sample_city == 1 | date_start==.;
	};

	* -- s2: asymmetric windows - short pre + long post - changing sample;
	if `2' == 2
	{;
		drop if date_start == .;
		replace sample_city = 0 if  mint>-1*`4';
		replace sample_city = 0 if  maxt<18;
		keep if sample_city == 1;
	};

	* -- s21: asymmetric windows - short pre + long post - changing sample - include old subway cities;
	if `2' == 21
	{;
		drop if date_start == .;
		replace sample_city = 0 if  mint>-1*`4';
		replace sample_city = 0 if  maxt<18;
		keep if sample_city == 1 | date_start < tm(2000m2);
	};

	* -- s22: asymmetric windows - short pre + long post - changing sample - include all cities;
	if `2' == 22
	{;
		replace sample_city = 0 if  mint>-1*`4';
		replace sample_city = 0 if  maxt<18;
		keep if sample_city == 1 | date_start == .;
	};

	* -- s3: symmetric windows - changing sample;
	if `2' == 3
	{;
		drop if date_start ==.;
		drop if date_start < tm(2000m2);
	};

	* -- s6: asymmetric windows - short pre + long post - constant sample;
	if `2' == 6
	{;
		drop if date_start == .;
		replace sample_city = 0 if  mint>-1*`4';
		replace sample_city = 0 if  maxt<`1' | maxt<18;
		keep if sample_city == 1;
	};

	* -- s61: asymmetric windows - short pre + long post - constant sample - include old subway cities;
	if `2' == 61
	{;
		drop if date_start == .;
		replace sample_city = 0 if  mint>-1*`4';
		replace sample_city = 0 if  maxt<`1' | maxt<18;
		keep if sample_city == 1 | date_start < tm(2000m2);
	};

	* -- s62: asymmetric windows - short pre + long post - constant sample - include all cities;
	if `2' == 62
	{;
		replace sample_city = 0 if  mint>-1*`4';
		replace sample_city = 0 if  maxt<`1' | maxt<18;
		keep if sample_city == 1 | date_start==.;
	};

	global post2 "ib20667.urbancode c.plus0#i.urbancode c.pre_window#i.urbancode c.post_window#i.urbancode";

end;

**********************************;
*  TIME DUMMIES FOR EVENT-STUDY  *;
**********************************;
cap program drop timedummies;
program define timedummies;

	*create time-dummies;
	global dist2event;
	global dist2event_b;
	global dist2event_se;
	foreach sign in "minus" "plus"
	{;
		local k = 1;
		while `k' <= `1'/`2'
		{;
			gen `sign'`k' = 0;
			if "`sign'" == "minus"
			{;
				local ub = -1*(`2'*`k'-`2'+1);
				local lb = -1*`k'*`2';
				disp "`sign'`k'";
				replace `sign'`k' = 1 if t <= `ub' & t >= `lb';
				replace `sign'`k' = 0 if t ==0;
			};
			if "`sign'" == "plus"
			{;
				local ub = `k'*`2';
				local lb = `2'*`k'-`2'+1;
				disp "`sign'`k'";
				replace `sign'`k' = 1 if t<= `ub' & t >=`lb';
				replace `sign'`k' = 0 if t ==0;
			};
			global dist2event "$dist2event `sign'`k'";
			global dist2event_b "$dist2event_b b_`sign'`k'";
			global dist2event_se "$dist2event_se se_`sign'`k'";
			local k = `k' + 1;
		};
	};
	gen plus0 =0;
	replace plus0 = 1 if t == 0;
	global dist2event "$dist2event $post2";

	*create global containing coefficient names;
	global coeffs;
	global ub = `1'/`2';
	foreach item in "_b" "_se"
	{;
		foreach sign in "minus" "plus"
		{;
			forvalues k = 1(1)$ub
			{;
				global coeffs "$coeffs (`item'[`sign'`k'])";
			};
		};
	};

	*remove reference period from globals;
	if `5' !=1
	{;
		local  refper =  ceil($reftime/`2');
		global refper = -ceil($reftime/`2');
		drop minus`refper';
		takefromglobal dist2event minus`refper';
		takefromglobal dist2event_b b_minus`refper';
		takefromglobal dist2event_se se_minus`refper';
		takefromglobal coeffs (_b[minus`refper']) (_se[minus`refper']);
	};
	if `5' ==1
	{;
		takefromglobal dist2event plus0;
	};

	if `3' == 2 | `3' == 21 | `3' == 22 | `3' == 3 | `3' == 6 | `3' == 61 | `3' == 62
	{;
		*local k = `4'/`2' + 1;
		local k = 2;
		while `k' <= `1'/`2'
		{;
			drop minus`k';
			takefromglobal dist2event minus`k';
			takefromglobal dist2event_b b_minus`k';
			takefromglobal dist2event_se se_minus`k';
			takefromglobal coeffs (_b[minus`k']) (_se[minus`k']);
			local k = `k' + 1;
		};
	};

	if `3' == 7
	{;
		local k = `4'/`2' + 1;
		while `k' <= `1'/`2'
		{;
			drop plus`k';
			takefromglobal dist2event plus`k';
			takefromglobal dist2event_b b_plus`k';
			takefromglobal dist2event_se se_plus`k';
			takefromglobal coeffs (_b[plus`k']) (_se[plus`k']);
			local k = `k' + 1;
		};
	};

end;

***************************************;
*     A.  DATA PREPARATION            *;
***************************************;
if 1 == 1
{;
*prepare specification settings;
global pre_;
global pre_x_;
if `y_log' > 0 global pre_ "log_";
if `x_log' > 0 global pre_x_ "log_";
if `x_sq'  > 0 global pre_x_ "sq_";
if `x_cu'  > 0 global pre_x_ "cu_";
global YK "3K 10K";
takefromglobal YK $XK;

*copy input-files to temp dir;
shell rm -r 'temp';
mkdir temp;
copy $data temp/main_data.dta;

*open dataset;
use temp/main_data.dta, clear;
sort urbancode date;

if `til2014' ==1
{;
	drop if date > tm(2014m12);
};

*keep desired product and setup for satellite reshape;
local stubs;
foreach stat in "mean" "count"
{;
	foreach ring in "10km" "25km" "50km" "150km"
	{;
		if "`stat'"=="mean" local stubs `stubs' aod_`stat'_`ring' log_aod_`stat'_`ring';
		if "`stat'"=="count" local stubs `stubs' aod_`stat'_`ring';
		foreach sat in "Aqua" "Terra"
		{;
			rename aod${XK}_`stat'_`sat'_`ring'${foot} aod_`stat'_`ring'_`sat';
		};
	};
};

*generate log aod for each disk;
foreach ring in "10km" "25km" "50km" "150km"
{;
	foreach sat in "Aqua" "Terra"
	{;
		gen log_aod_mean_`ring'_`sat' = log(aod_mean_`ring'_`sat'+1);
	};
};

*months pre/post subway opening;
gen aux = date if date == date_start;
egen aux2 = max(aux), by(urbancode);
gen t  = date-aux2;
drop aux aux2;

*operational stations at opening;
gen aux = operational if date == date_start;
egen operational_start = max(aux), by(urbancode);
drop aux;

*track line expansions;
sort urbancode date;
by urbancode: gen expansion = (subway_lines > subway_lines[_n-1]);
by urbancode: gen expansion_num = sum(expansion);

*keep only months where we have AOD;
keep if date >= tm(2000m2);
keep if date<=tm(2017m12);

*generate a categorical variable for calendar month of the year;
gen day = dofm(date);
gen month = month(day);

*generate numerical versions of categorical vars;
sort urbancode date;
egen continent_n = group(continent);
gen hemis = 0;
replace hemis = 1 if latitude >=0;

*define C1 controls - Year and Season Effects;
global C1  "i.year#i.continent_n";
global C11 "i.urbancode#i.month";
global C111 "i.hemis#i.date";

*generate numerical versions of cityXmonth fixed effects;
egen C1 = group(year continent_n);
egen C11 = group(urbancode month);
egen C111 = group(hemis date);

*define C2 controls by ring radius - Climate;
foreach ring in "10km" "25km" "50km" "150km"
{;
	global C2_`ring';
	global sq_C2_`ring';
	global cu_C2_`ring';
	global log_C2_`ring';
	foreach clim of local climlist
	{;
		gen sq_`clim'_`ring' = `clim'_`ring'*`clim'_`ring';
		gen cu_`clim'_`ring' = `clim'_`ring'*`clim'_`ring'*`clim'_`ring';
		gen log_`clim'_`ring' = log(`clim'_`ring'+1);
		global C2_`ring' "${C2_`ring'} `clim'_`ring'";
		global C2_`ring'_Xcont "${C2_`ring'_Xcont} c.`clim'_`ring'#i.continent_n";
		global sq_C2_`ring' "${sq_C2_`ring'} `clim'_`ring' sq_`clim'_`ring'";
		global sq_C2_`ring'_Xcont "${sq_C2_`ring'_Xcont} c.`clim'_`ring'#i.continent_n c.sq_`clim'_`ring'#i.continent_n";
		global cu_C2_`ring' "${cu_C2_`ring'} `clim'_`ring' sq_`clim'_`ring' cu_`clim'_`ring'";
		global log_C2_`ring' "${log_C2_`ring'} log_`clim'_`ring'";
	};
};

*define C4 controls - Population and Output;
global C4;
global sq_C4;
global cu_C4;
global log_C4;
foreach var in "gdp" "city_pop"
{;
	gen sq_`var' = `var'*`var';
	gen cu_`var' = `var'*`var'*`var';
	gen log_`var'= log(`var');
	global C4 "${C4} `var'";
	global sq_C4 "${sq_C4} `var' sq_`var'";
	global cu_C4 "${cu_C4} `var' sq_`var' cu_`var'";
	global log_C4 "${log_C4} log_`var'";
};

*save the data;
save temp/main_data.dta, replace;

*reshave and save again;
reshape long `stubs', i(urbancode date) j(satellite) s;
replace satellite = substr(satellite,2,.);
save temp/main_data_reshape.dta, replace;
};

***************************************;
*     B.  DATA ANALYSIS               *;
***************************************;
*window-specific directory;
if `overwrite' == 1
{;
	shell rm -r "${tables}";
	mkdir "${tables}";
	shell rm -r "${figures}";
	mkdir "${figures}";
};

***********************************;
*     MAIN REGRESSION TABLES      *;
***********************************;
if 1 == `gateTables'
{;

foreach sample of local samples
{;
	if `sample' == 1
	{;
		local bins = "18";
		local windows "18";
		local lwindows "18";
	};

	if `sample' == 11
	{;
		local bins = "18";
		local windows "18";
		local lwindows "18";
	};

	if `sample' == 12
	{;
		local bins = "18";
		local windows "18";
		local lwindows "18";
	};

	if `sample' == 2
	{;
		local bins = "12";
		local windows "60 72 84 96";
		local lwindows "18";
	};

	if `sample' == 21
	{;
		local bins = "12";
		local windows "60 72 84 96";
		local lwindows "18";
	};

	if `sample' == 22
	{;
		local bins = "12";
		local windows "60 72 84 96";
		local lwindows "18";
	};

	if `sample' == 3
	{;
		local bins = "12";
		local windows "72";
		local lwindows "72";
	};

	if `sample' == 6
	{;
		local bins = "48";
		local windows "48";
		local lwindows "18";
	};

	if `sample' == 61
	{;
		local bins = "48";
		local windows "48";
		local lwindows "18";
	};

	if `sample' == 62
	{;
		local bins = "48";
		local windows "48";
		local lwindows "18";
	};

	if `sample' == 7
	{;
		local bins = "12";
		local windows "24 36 48 60 72";
		local lwindows "12";
	};

	foreach bin of local bins
	{;
	foreach window of local windows
	{;
	foreach lwindow of local lwindows
	{;
		foreach ring of local radlist
		{;
			foreach restriction of local restrictions
			{;
			foreach het of local hets
			{;

				clear;
				global prefix "";
				global inter "";

				if $expandlines == 1
				{;
					global prefix "LineEvents_${line_lb}_${line_ub}_";
					if $no_overlap == 1 {; global prefix "${prefix}noverlap_"; };
					if $no_newcities == 1 {; global prefix "${prefix}maincities_"; };
				};

				cd "${tables}";

				if `sample' == 1 | `sample' == 11 | `sample' == 12
				{;
					local lwindow = `window';
				};

				*prepare main_data (with reshape);
				windowsetup `window' `sample' _reshape `lwindow' $expandlines ;

				*gen Asia dummy;
				gen asia = (continent == "Asia");

				*gen China dummy;
				gen china = (country == "China");

				*gen dummy for top/bottom gdp per capita dist in 2000;
				bys urbancode: gen gdp2000 = gdp if year==2000;
				bys urbancode: egen mgdp2000 = min(gdp2000);
				bys urbancode: gen nn = _n;
				sum mgdp2000 if nn==1 & sample_city18 == 1, d	;
				gen poor = ( mgdp2000 <= r(p50) );
				drop gdp2000 mgdp2000 nn;

				*gen dummy for stations at opening;
				bys urbancode: gen nn = _n;
				sum operational_start if nn==1 & sample_city18 == 1, d	;
				gen bigopen = ( operational_start > r(p50) );
				drop nn;

				*gen dummy for top/bottom citypop dist in 2000;
				bys urbancode: gen citypop2000 = city_pop if year==2000;
				bys urbancode: egen mcitypop2000 = min(citypop2000);
				bys urbancode: gen nn = _n;
				sum mcitypop2000 if nn==1 & sample_city18 == 1, d	;
				gen large = ( mcitypop2000 > r(p50) );
				drop citypop2000 mcitypop2000 nn;

				*gen dummy for stations/population at opening;
				bys urbancode: gen citypopOpen = city_pop if t==0;
				bys urbancode: egen mcitypopOpen = min(citypopOpen);
				bys urbancode: gen relOpen = operational_start/mcitypopOpen;
				bys urbancode: gen nn = _n;
				sum relOpen if nn==1 & sample_city18 == 1, d	;
				gen bigRelativeOpen = ( relOpen > r(p50) );
				drop nn citypopOpen mcitypopOpen relOpen;

				*gen dummy for top/bottom precipitation dist in 2000;
				bys urbancode: gen pre_post = pre_`ring' if year==2000;
				bys urbancode: egen mpre_post = mean(pre_post);
				bys urbancode: gen nn = _n;
				sum mpre_post if nn==1 & sample_city18 == 1, d;
				gen rainy = ( mpre_post > r(p50) );
				drop pre_post mpre_post nn;

				*gen dummy for top/bottom wind dist in 2000;
				bys urbancode: gen wnd_post = wnd_speed_25km if year == 2000;
				bys urbancode: egen mwnd_post = mean(wnd_post);
				bys urbancode: gen nn = _n;
				sum mwnd_post if nn==1 & sample_city18 == 1, d;
				gen windy = ( mwnd_post > r(p50) );
				drop wnd_post mwnd_post nn;

				*gen dummy for top/bottom elevation mean dist;
				bys urbancode: gen nn = _n;
				sum elev_mean_25km if nn==1 & sample_city18 == 1, d;
				gen high_altitude = ( elev_mean_25km > r(p50) );
				drop nn;

				*gen dummy for top/bottom elevation range dist;
				bys urbancode: gen nn = _n;
				sum elev_range_25km if nn==1 & sample_city18 == 1, d;
				gen high_range = ( elev_range_25km > r(p50) );
				drop nn;

				*gen dummy for top/bottom density dist;
				bys urbancode: gen nn = _n;
				sum linear_b1 if nn==1 & sample_city18 == 1, d;
				gen dense = ( linear_b1 <= r(p50) );
				drop nn;

				*gen dummy for top/bottom AOD in 18 months pre-window;
				bys urbancode: gen prewindow_aod = ${pre_}aod_mean_`ring' if t>=-`lwindow' & t<0;
				bys urbancode: egen mprewindow_aod = mean(prewindow_aod);
				bys urbancode: gen nn = _n;
				sum mprewindow_aod if nn==1 & sample_city18 == 1, d;
				gen hiAOD18m = ( mprewindow_aod > r(p50) );
				drop prewindow_aod mprewindow_aod nn;

				*gen dummy for top/bottom AOD in 2000;
				bys urbancode: gen prewindow_aod = ${pre_}aod_mean_`ring' if year == 2000;
				bys urbancode: egen mprewindow_aod = mean(prewindow_aod);
				bys urbancode: gen nn = _n;
				sum mprewindow_aod if nn==1 & sample_city18 == 1, d;
				gen hiAOD = ( mprewindow_aod > r(p50) );
				drop prewindow_aod mprewindow_aod nn;

				*gen dummy for top/bottom city_growth 00-10;
				bys urbancode: gen citypop2000 = city_pop if year==2000;
				bys urbancode: egen mcitypop2000 = min(citypop2000);
				bys urbancode: gen citypop2010 = city_pop if year==2010;
				bys urbancode: egen mcitypop2010 = min(citypop2010);
				gen city_growth = (mcitypop2010-mcitypop2000)/mcitypop2000;
				bys urbancode: gen nn = _n;
				sum city_growth if nn==1 & sample_city18 == 1, d	;
				gen fast_growing = ( city_growth > r(p50) );
				drop mcitypop20* citypop20* city_growth nn;

				*gen dummy for cities with no subway;
				gen newcities = 0 ;
				replace newcities = 1 if date_start>=tm(2013m6) & date_start != .;

				*gen dummy for December openings;
				gen dec_open_tmp = 0 ;
				replace dec_open_tmp = 1 if date == date_start & month == 12;
				bys urbancode: egen december_open = max(dec_open_tmp);
				drop dec_open_tmp;

				*heterogeneity settings;
				if `het' == 1{; global inter "asia"; global prefix "${prefix}InteractAsia"; };
				if `het' == 2{; global inter "poor"; global prefix "${prefix}InteractPoor"; };
				if `het' == 3{; global inter "bigopen"; global prefix "${prefix}InteractBigOpen"; };
				if `het' == 4{; global inter "large"; global prefix "${prefix}InteractLarge"; };
				if `het' == 5{; global inter "bigRelativeOpen"; global prefix "${prefix}InteractBigRelativeOpen"; };
				if `het' == 6{; global inter "rainy"; global prefix "${prefix}InteractRainy"; };
				if `het' == 7{; global inter "hiAOD"; global prefix "${prefix}InteractHighAOD"; };
				if `het' == 8{; global inter "fast_growing"; global prefix "${prefix}InteractFastGrowing"; };
				if `het' == 9{; global inter "newcities"; global prefix "${prefix}InteractPost2014"; };
				if `het' == 10{; global inter "hiAOD18m"; global prefix "${prefix}InteractHighAOD18m"; };
				if `het' == 11{; global inter "china"; global prefix "${prefix}InteractChina"; };
				if `het' == 12{; global inter "windy"; global prefix "${prefix}InteractWindy"; };
				if `het' == 13{; global inter "high_altitude"; global prefix "${prefix}InteractHighAlt"; };
				if `het' == 14{; global inter "high_range"; global prefix "${prefix}InteractHighElevRange"; };
				if `het' == 15{; global inter "dense"; global prefix "${prefix}InteractDense"; };

				*generate time dummies for plot;
				timedummies `window' `bin' `sample' `lwindow' 0;

				if `sample' == 2 | `sample' == 21 | `sample' == 22 | `sample' == 6 | `sample' == 61 | `sample' == 62
				{;
				**MW: use low AOD sample;
					keep if hiAOD == 0 | date_start<tm(2000m2) | date_start==.;
				};

				if `het' >= 1
				{;
					gen plus1_$inter = plus1 * $inter ;
					takefromglobal dist2event $post2 ;
					global dist2event ${dist2event} plus1_$inter $post2;
				};

				*no restrictions;
				if `restriction' == 1
				{;
					local suffix = "fs${foot}";
					local weights = "";
				};

				*weight obs by pixelcount;
				if `restriction' == 2
				{;
					local suffix = "pw${foot}";
					local weights = "[aw=aod_count_`ring']";
				};

				*drop low pixel count;
				if `restriction' == 3
				{;
					local suffix = "dlc${foot}";
					local weights = "" ;
					bys satellite: egen p10 = pctile(aod_count_`ring'), p(10);
					replace ${pre_}aod_mean_`ring' = . if aod_count_`ring' < p10;
				};

				*drop rainy months (wet days);
				if `restriction' == 4
				{;
					drop if wet_`ring' > 15;
				};

				*drop outlier AOD months;
				if `restriction' == 5
				{;

					sort urbancode satellite month aod_mean_`ring';
					by urbancode satellite month: gen n = _n if aod_mean_`ring'!=.;
					by urbancode satellite month: egen maxn = max(n) if aod_mean_`ring'!=.;
					drop if n==1;
					drop if n==maxn;
					drop maxn n;
				};

				local lob = `lwindow';
				local hib =  `window';

				eststo clear;
				capture estimates clear;

				if `rider' == 0
				{;

				gen citybymonth = 1;

				if `sample' == 6
				{;
				*Specification (0) ;
				display "reg ${pre_}aod_mean_`ring' ${dist2event} `weights', $error";
				reg ${pre_}aod_mean_`ring' ${dist2event} `weights', $error;
				set seed 123456789;
				boottest plus1, noci nograph;
				global boot_pv = r(p);
				display $boot_pv;
				reg ${pre_}aod_mean_`ring' ${dist2event} `weights', $error;
				eststo reg0;
				countevents;
				estadd ysumm;
				estadd scalar sc_Nevents = $Nevents;
				estadd scalar sc_Ncities = $Ncities;
				estadd scalar bs_p = $boot_pv;

				*Specification (1) ;
				display "reg ${pre_}aod_mean_`ring' ${dist2event} $C1 satdum `weights', $error";
				reg ${pre_}aod_mean_`ring' ${dist2event} $C1 satdum `weights', $error;
				set seed 123456789;
				boottest plus1, noci nograph;
				global boot_pv = r(p);
				display $boot_pv;
				reg ${pre_}aod_mean_`ring' ${dist2event} $C1 satdum `weights', $error;
				eststo reg1;
				countevents;
				estadd ysumm;
				estadd scalar sc_Nevents = $Nevents;
				estadd scalar sc_Ncities = $Ncities;
				estadd scalar bs_p = $boot_pv;

				*Specification (2) ;
				display "areg ${pre_}aod_mean_`ring' ${dist2event} $C1 satdum citybymonth `weights', a(C11) $error";
				areg ${pre_}aod_mean_`ring' ${dist2event} $C1 satdum citybymonth `weights', a(C11) $error;
				set seed 123456789;
				boottest plus1, noci nograph;
				global boot_pv = r(p);
				areg ${pre_}aod_mean_`ring' ${dist2event} $C1 satdum citybymonth `weights', a(C11) $error;
				eststo reg2;
				countevents;
				estadd ysumm;
				estadd scalar sc_Nevents = $Nevents;
				estadd scalar sc_Ncities = $Ncities;
				estadd scalar bs_p = $boot_pv;
				};
				*Specification (3) ;
				display "areg ${pre_}aod_mean_`ring' ${dist2event} $C1 satdum citybymonth ${${pre_x_}C2_`ring'} aod_count_`ring' `weights', a(C11) $error";
				areg ${pre_}aod_mean_`ring' ${dist2event} $C1 satdum citybymonth ${${pre_x_}C2_`ring'} aod_count_`ring' `weights', a(C11) $error;
				set seed 123456789;
				boottest plus1, noci nograph;
				global boot_pv = r(p);
				display $boot_pv;
				areg ${pre_}aod_mean_`ring' ${dist2event} $C1 satdum citybymonth ${${pre_x_}C2_`ring'} aod_count_`ring' `weights', a(C11) $error;
				eststo reg3;
				countevents;
				estadd ysumm;
				estadd scalar sc_Nevents = $Nevents;
				estadd scalar sc_Ncities = $Ncities;
				estadd scalar bs_p = $boot_pv;

				*Specification (4) ;
				display "areg ${pre_}aod_mean_`ring' ${dist2event} $C1 satdum citybymonth ${${pre_x_}C2_`ring'_Xcont} c.aod_count_`ring'#i.continent_n `weights', a(C11) $error";
				areg ${pre_}aod_mean_`ring' ${dist2event} $C1 satdum citybymonth ${${pre_x_}C2_`ring'_Xcont} c.aod_count_`ring'#i.continent_n `weights', a(C11) $error;
				set seed 123456789;
				boottest plus1, noci nograph;
				global boot_pv = r(p);
				display $boot_pv;
				areg ${pre_}aod_mean_`ring' ${dist2event} $C1 satdum citybymonth ${${pre_x_}C2_`ring'_Xcont} c.aod_count_`ring'#i.continent_n `weights', a(C11) $error;
				eststo reg4;
				countevents;
				estadd ysumm;
				estadd scalar sc_Nevents = $Nevents;
				estadd scalar sc_Ncities = $Ncities;
				estadd scalar bs_p = $boot_pv;

				gen after = (t>0);
				gen plus1Xt = plus1*t;

				if `het' == 0 & `sample' == 1 | `het' == 0 & `sample' == 11 | `het' == 0 & `sample' == 12
				{;
				*Specification (8) ;
				display "areg ${pre_}aod_mean_`ring' ${dist2event} plus1Xt $C1 satdum citybymonth ${${pre_x_}C2_`ring'_Xcont} c.aod_count_`ring'#i.continent_n c.t#i.urbancode `weights', a(C11) $error";
				areg ${pre_}aod_mean_`ring' ${dist2event} plus1Xt $C1 satdum citybymonth ${${pre_x_}C2_`ring'_Xcont} c.aod_count_`ring'#i.continent_n c.t#i.urbancode `weights', a(C11) $error;
				eststo reg8;
				countevents;
				estadd ysumm;
				estadd scalar sc_Nevents = $Nevents;
				estadd scalar sc_Ncities = $Ncities;

				*Specification (12) ;
				display "areg ${pre_}aod_mean_`ring' ${dist2event} $C1 satdum citybymonth ${${pre_x_}C2_`ring'_Xcont} c.aod_count_`ring'#i.continent_n c.t#i.urbancode#i.after `weights', a(C11) $error";
				areg ${pre_}aod_mean_`ring' ${dist2event} $C1 satdum citybymonth ${${pre_x_}C2_`ring'_Xcont} c.aod_count_`ring'#i.continent_n c.t#i.urbancode#i.after `weights', a(C11) $error;
				eststo reg12;
				countevents;
				estadd ysumm;
				estadd scalar sc_Nevents = $Nevents;
				estadd scalar sc_Ncities = $Ncities;
				};

				drop after plus1Xt citybymonth;

				if `het' != 0 | `sample' != 1 & `sample' != 11 & `sample' != 12
				{;
				foreach format in "csv" "tex"
				{;
				esttab using "${prefix}Table_s`sample'_`ring'_`lob'BE_to_`hib'AE_`bin'b_`suffix'" , replace
					drop(*plus0* _cons *pre_window* *post_window* *aod_count* *urbancode*) nomti
					indicate
					(
						"satellite fixed effects = satdum"
						"continent-by-year fixed effects = *year*"
						"city-by-calendar month fixed effects = citybymonth"
						"climate controls = ${${pre_x_}C2_`ring'}"
						"climate controls X continent f.e. = *.continent_n#c.*"
					)
					scalars("ymean Mean dep. var." "bs_p Bootstrap p-value" "r2 R-squared" "r2_a adjusted R-squared" "sc_Nevents Number of events" "sc_Ncities Number of cities" "N Observations")
					sfmt(%9.2f %9.3f %9.2f %9.2f %9.0g %9.0g %9.0g)
					obslast
					b(%9.4f) se(%9.4f) `format' star(* 0.10 ** 0.05 *** 0.01)
					nonotes addnotes("Dependent variable: Mean AOD in a `ring' disk centered around the city center."
					"All specifications include city fixed effects, city-specific pre-window indicators, city-specific post-window indicators, and city-specific period-0 indicators."
					"Climate controls (linear and quadratic): temperature, precipitation, cloud cover, vapor pressure, frost days, and pixel count."
					"Standard errors clustered at the city level in parentheses. Stars denote significance levels: * 0.10, ** 0.05, *** 0.01.");
				};
				};

				if `het' == 0 & `sample' == 1 | `het' == 0 & `sample' == 11 | `het' == 0 & `sample' == 12
				{;
				foreach format in "csv" "tex"
				{;
				esttab using "${prefix}Table_s`sample'_`ring'_`lob'BE_to_`hib'AE_`bin'b_`suffix'" , replace
					drop(*plus0* _cons *pre_window* *post_window* *aod_count* *urbancode*) nomti
					indicate
					(
					"satellite fixed effects = satdum"
					"continent-by-year fixed effects = *year*"
					"city-by-calendar month fixed effects = citybymonth"
					"climate controls = ${${pre_x_}C2_`ring'}"
					"climate controls X continent f.e. = *.continent_n#c.*"
					"city-level trend = *urbancode#c.t"
					"city-level pre/post trends = *after#c.t"
					)
					scalars("ymean Mean dep. var." "bs_p Bootstrap p-value" "r2 R-squared" "r2_a adjusted R-squared" "sc_Nevents Number of events" "sc_Ncities Number of cities" "N Observations")
					sfmt(%9.2f %9.2f %9.2f %9.2f %9.0g %9.0g %9.0g)
					obslast
					b(%9.4f) se(%9.4f) `format' star(* 0.10 ** 0.05 *** 0.01)
					nonotes addnotes("Dependent variable: Mean AOD in a `ring' disk centered around the city center."
					"All specifications include city fixed effects, city-specific pre-window indicators, city-specific post-window indicators, and city-specific period-0 indicators."
					"Climate controls (linear and quadratic): temperature, precipitation, cloud cover, vapor pressure, frost days, and pixel count."
					"Standard errors clustered at the city level in parentheses. Stars denote significance levels: * 0.10, ** 0.05, *** 0.01.");
				};
				};
				};
			};
			};
		};
	};
	};
	};
	cd $home;
};
***********************************;
*   END OF REGRESSION TABLES      *;
***********************************;
};

************;
* CLEAN UP *;
************;
shell rm -r 'temp';
cd dofiles;
/* log close;
exit; */
