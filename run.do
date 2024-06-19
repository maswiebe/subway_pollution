* set path: uncomment the following line and set the filepath for the folder containing this run.do file
*global root_mw "[location of replication archive]"
global data_mw "$root_mw/data"
global code_mw "$root_mw/code"
global tables_mw "$root_mw/output/tables"
global figures_mw "$root_mw/output/figures"
global gc_data "$data_mw/GendronCarrier_etal_2020_replication/data_proccessing"

* Stata version control
version 15

* configure library environment
do "$code_mw/_config.do"

* Figure 4: event study
* high AOD sample
global aod_mw 1
* this creates output folder
do "$code_mw/event_study_1_wiebe.do"
* low AOD sample
global aod_mw 0
do "$code_mw/event_study_1_wiebe.do"

* Table 5: Table 4 with low AOD
do "$code_mw/event_study_5a_low_wiebe.do"

* Table 6: Table 5 (long-run effects) with low AOD
    * 5b: panel A
    * 5c,d,e: does panel B of replication of Table 5
do "$code_mw/event_study_5b_low_wiebe.do"
do "$code_mw/event_study_5c_low_wiebe.do"
do "$code_mw/event_study_5d_low_wiebe.do"
do "$code_mw/event_study_5e_low_wiebe.do"

* Table 7: replication of Table 6 (spatial decay) with low AOD
do "$code_mw/event_study_6_low_wiebe.do"

do "$code_mw/gather_table456_lowaod_wiebe.do"

* Tables 1,2: AOD threshold: p40, p60
global type_mw "40"
do "$code_mw/event_study_5a_aod_wiebe.do"
global type_mw "60"
do "$code_mw/event_study_5a_aod_wiebe.do"

* Table 3: continuous AOD
do "$code_mw/event_study_4_ctsaod_wiebe.do"
do "$code_mw/event_study_4_ctsaod_hiaod_wiebe.do"
do "$code_mw/event_study_4_ctsaod_loaod_wiebe.do"
* manually create latex for Table 3

* Table 4: 2001 AOD
global type_mw "2001"
do "$code_mw/event_study_5a_aod2001_wiebe.do"

* ridership
do "$code_mw/ridership_wiebe.do"

* averted deaths
    * run in order
do "$code_mw/who_mortality_wiebe.do"
do "$code_mw/event_study_4_fig5_wiebe.do"
do "$code_mw/averted_deaths_wiebe.do"