**MW: I use the data saved as a temporary file on line 571 of event_study_9.do
use "$data_mw/main_data_reshape", clear

gen daily_ridership_per_capita=daily_ridership/(city_pop)
replace daily_ridership = 0 if t < 0
replace daily_ridership_per_capita = 0 if t < 0

* global expandlines   = 0
  * use =1 when using subway expansions
gen expansion_number =1

bys urbancode expansion_number: egen mint = min(t)
bys urbancode expansion_number: egen maxt = max(t)

*Sample-specific restrictions
gen sample_city = 1
gen sample_city18 = 1
replace sample_city18 = 0 if  mint>-18
replace sample_city18 = 0 if  maxt<18

*gen dummy for daily_riderhsip per capita one year after opening
bys urbancode: gen ridership_after_12m = daily_ridership_per_capita if t==12
bys urbancode: egen mridership_after_12m = min(ridership_after_12m)
bys urbancode: gen nn = _n
sum mridership_after_12m if nn==1 & sample_city18 == 1, d
gen ride_per_cap_12m = ( mridership_after_12m > r(p50) ) if mridership_after_12m !=.
drop nn ridership_after_12m mridership_after_12m

* total
bys urbancode: gen ridership_after_12m = daily_ridership if t==12
bys urbancode: egen mridership_after_12m = min(ridership_after_12m)
bys urbancode: gen nn = _n
sum mridership_after_12m if nn==1 & sample_city18 == 1, d
gen ride_12m = ( mridership_after_12m > r(p50) ) if mridership_after_12m !=.
drop nn ridership_after_12m mridership_after_12m

tab ride_per_cap_12m
tab ride_12m

* create variables for collapse
bys urbancode: gen ridership_after_12m_pc = daily_ridership_per_capita if t==12
bys urbancode: egen mridership_after_12m_pc = min(ridership_after_12m_pc)

bys urbancode: gen ridership_after_12m = daily_ridership if t==12
bys urbancode: egen mridership_after_12m = min(ridership_after_12m)

*gen dummy for top/bottom AOD in 2000
* fill in macros:
    * pre = ""
    * ring = 10km
bys urbancode: gen prewindow_aod = aod_mean_10km if year == 2000
bys urbancode: egen mprewindow_aod = mean(prewindow_aod)
bys urbancode: gen nn = _n
sum mprewindow_aod if nn==1 & sample_city18 == 1, d
gen hiAOD = ( mprewindow_aod > r(p50) )
drop prewindow_aod mprewindow_aod nn
* this gives n=43; have one city with ridership that is excluded from the regression
    * need to use the estimation sample

preserve
collapse mridership_after_12m mridership_after_12m_pc ride_12m ride_per_cap_12m hiAOD, by(urbancode urbanname)
drop if urbanname=="Hefei"
* city with ridership data that is not included in the regression sample

tab ride_12m hiAOD
* 7 out of 42 don't match
  * 4 are high pollution but low ridership, and 3 are high ridership but low pollution.
tab ride_per_cap_12m hiAOD
* 17 our of 42 don't match
  * 9 are high pollution but low ridership, and 8 are high ridership but low pollution.

restore