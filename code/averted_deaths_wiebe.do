cd "$gc_data/data_analysis/WHO_mortality/"
* need to run who_mortality_wiebe.do first, to populate /temp/

global deathrates "../../data/WHO_mortality/source/WHO"

* get isocode3 key for merge
import delimited "${deathrates}/iso3codes.txt", clear
keep name alpha3
rename alpha3 countrycode
rename name country
save temp/temp, replace

* prepare relative risks for merge
use temp/relativerisk, clear
*drop *_lb *_ub
*ds rr*
    * variables not found
foreach vari in `r(varlist)' {
	gen `vari'_pre = `vari'
	gen `vari'_post = `vari'
	drop `vari'
}
gen pred_pm25_pre = pm25
gen pred_pm25_post = pm25
drop pm25
save temp/relativerisk, replace

* reshape deathrates again for merge
use temp/deathrates, clear
ds death* popfr
foreach vari in `r(varlist)' {
	rename `vari' `vari'_
}
replace age = subinstr(age,"-","_",.)
replace age = subinstr(age,"+","plus",.)
reshape wide death* popfr, i(countrycode year) j(age) s
save temp/deathrates, replace


* merge everything into one dataset
use temp/cities_pm25, clear
recast str52 country, force
merge m:1 country using temp/temp, nogen keep(matched)
merge m:1 countrycode year using temp/deathrates, nogen keep(matched)
*merge m:1 pred_pm25_pre using temp/relativerisk, keepus(*_pre) nogen keep(matched)
*merge m:1 pred_pm25_post using temp/relativerisk, keepus(*_post) nogen keep(matched)
	**MW: doesn't merge well with these

* calculate birthrate;
gen birthrate = popfr_0_4/5

su city_pop
* 3860

su birthrate
* 0.014

*-------------------------------------------------------------------------------
* deaths averted: original

merge 1:1 urbancode using "$data_mw/het_te.dta"
drop if _m==2
drop _m

* mortality estimate from econ lit;
* avoided_deaths_0_1

* hi pollution
preserve
keep if hiAOD==1
gen avoided_deaths_0_1_wrong = birthrate*(city_pop*1000)*2.9*(10/100000)
    * this is what their code uses; but should be 3.2
gen avoided_deaths_0_1 = birthrate*(city_pop*1000)*3.2*(10/100000)
su avoided_deaths_0_1*
* original: 22.5 deaths averted, using 2.9 instead of 3.2=0.028*114.6
    * see footnote 6
* correct: 24.88
restore

*-------------------------------------------------------------------------------
* distribution of averted deaths, high-pollution cities

preserve
keep if hiAOD==1
gen avoided_deaths_0_1 = birthrate*(city_pop*1000)*3.2*(10/100000)
gen cont = avoided_deaths_0_1/29
* contribution to average, in levels
gen share = cont/24.88
* contribution to average, percent

*bro urbanname v2 city_pop birthrate avoided_deaths_0_1 cont share
* Delhi is 18%
* Delhi: 129 deaths averted
* Mumbai: 114

set scheme plotplainblind
tw (hist avoided_deaths_0_1 if hiAOD==1,  xtitle("Averted infant deaths, per year") color(red%30) freq width(10)), legend(order(1 "High pollution" 2 "Low pollution"))
*title("Distribution of averted deaths, by city") subtitle("High pollution cities")
graph export "$figures_mw/ad_dist_hiaod.png", replace

restore

*-------------------------------------------------------------------------------
*  distribution of averted deaths, city-specific treatment effect, all cities

gen ad = birthrate*(city_pop*1000)*(v2*-114.6)*(10/100000)
* need to multiply beta_hat by -1 to put in terms of deaths averted
su ad
* 2.13; 2 deaths averted on average

* unweighted average by initial pollution
su ad if hiAOD==1
* 15 deaths averted in high pollution cities
su ad if hiAOD==0
* 11 deaths caused in low pollution cities

*bro urbanname v2 city_pop birthrate ad
* Delhi: 371 averted
* Chongqing: -179
* Mumbai: -170


tw (hist ad if hiAOD==1,  xtitle("Averted infant deaths, per year") color(red%30) freq width(10)) (hist ad if hiAOD==0, color(blue%30) freq width(10)), legend(order(1 "High pollution" 2 "Low pollution") pos(6) rows(1))
*title("Distribution of averted deaths, by city")
graph export "$figures_mw/ad_dist_beta_i.png", replace

*----------------
*** contributions to unweighted average

* high pollution cities
preserve
keep if hiAOD==1
sort ad
gen ad_cont = ad*(1/29)
egen ad_manual = total(ad_cont)
bro urbanname v2 city_pop ad ad_cont ad_manual
restore

* unweighted average: 15
* Delhi: 13
* Chengdu: 4
* Chongqing: -6
* Mumbai: -6

*-----------
* low pollution cities
preserve
keep if hiAOD==0
sort ad
gen ad_cont = ad*(1/29)
egen ad_manual = total(ad_cont)
bro urbanname v2 city_pop ad ad_cont ad_manual
restore

* Chennai: -3.4