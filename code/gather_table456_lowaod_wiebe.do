**MW: create table for Table 4 replications
cd "$gc_data/data_analysis"
* note: comments using `*` need to be ended with `;`

/**********************************************

gather_R1_v5.do

gather all tables and figures that we want to use for the paper
and organize them into latex output.

**********************************************/

#delimit;
*set up;
program drop _all;
***************************************;
program def clean_quotes;
	gen start="start";
	gen end="end";
	order start;
	foreach varname of var start-end{;
		replace `varname' = subinstr(`varname',`"""',"",.);
		replace `varname' = subinstr(`varname',`"="',"",.);
		replace `varname' = cond(`varname'=="No","N", `varname');
		replace `varname' = cond(`varname'=="Yes","Y", `varname');
		replace `varname' = cond(`varname'=="No\\","N\\", `varname');
		replace `varname' = cond(`varname'=="Yes\\","Y\\", `varname');
		};
	drop start end;
	end;

**********************************;
program def clean_row_names;
	replace v1_1 = subinstr(v1_1,"dep. var.","$ \text{\textsc{aod}}$",.);
	replace v1_1 = subinstr(v1_1,"plus1Xt","post $\times$ x",.);
	replace v1_1 = subinstr(v1_1,"plus1","post",.);
	replace v1_1 = subinstr(v1_1,"large","$\times\;x$",.);
	replace v1_1 = subinstr(v1_1,"calendar","cal.",.);
	replace v1_1 = subinstr(v1_1,"continent","cont.",.);
	replace v1_1 = subinstr(v1_1,"month ","mo. ",.);
	replace v1_1 = subinstr(v1_1,"fixed effects","",.);
	replace v1_1 = subinstr(v1_1,"f.e.","",.);
	replace v1_1 = subinstr(v1_1,"Number of","\#",.);
	replace v1_1 = subinstr(v1_1,"controls","",.);
	replace v1_1 = subinstr(v1_1,"adjusted","adj.",.);
	replace v1_1 = subinstr(v1_1,"Bootstrap","bootstrap",.);
	replace v1_1 = subinstr(v1_1,"Mean","\hline Mean",.);
	replace v1_1 = subinstr(v1_1,"R-squared","$ R^2$",.);
	replace v1_1 = subinstr(v1_1,"X", "$\times$",.);
	replace v1_1 = subinstr(v1_1,"-by-","$\times$",.);
	replace v1_1 = subinstr(v1_1,"-level","",.);
	replace v1_1 = subinstr(v1_1,"  "," ",.);
	replace v1_1 = subinstr(v1_1,"  "," ",.);
	replace v1_1 = subinstr(v1_1,"  "," ",.);
	replace v1_1 = subinstr(v1_1,"_"," ",.);
	replace v1_1 = trim(v1_1);
	*drop adjusted r2 and climate row;
	drop if strmatch(`"adj. $ R^2$"',v1_1);
	drop if trim(v1_1)=="climate";
	end;

******************************************;
******************************************;
*MAIN;
******************************************;
******************************************;
clear;
set more on;
set matsize 6000;
set more 1;
set scheme s1mono;
postutil clear;
*make empty temp directory;
shell rm -r 'gather_R1';
mkdir gather_R1;



** Table 4: MAIN RESULTS: HIGH AOD CITIES ONLY **;
global input_tables 	"
			Table_s6_10km_18BE_to_18AE_18b_fs
			Table_s62_10km_18BE_to_18AE_18b_fs
			";

*gather up all the columns we want into one stata file;
clear;
local i=1;
foreach table of global input_tables {;
	display "in condense tables";
	display "output_event_study/tables/`table'.csv";
	local in "output_event_study/tables/`table'.csv";
	import delimited `in',  stringcols(_all);
	if `i'==1{;
		keep v1 v2 v3 v4 v5 v6;
		};
	if `i'==2{;
		keep v3;
		};
	rename v* v*_`i';
	gen row=_n;
	if `i'==1{;
		save gather_R1/output_table,replace;
		};
	if `i'>1{;
		merge 1:1 row using gather_R1/output_table;
		drop _merge;
		save gather_R1/output_table,replace;
		};
	clear;
	local i = `i'+1;
	};
*organize for output to latex;
use gather_R1/output_table,clear;
drop if row>=16;
drop if (row==1);
insobs 1;
replace row = -1 if row == .;
replace v1_1 = "{
\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}
\begin{tabular}{l*{8}{c}}
\hline\hline
        &\multicolumn{1}{c}{(1)}         &\multicolumn{1}{c}{(2)}         &\multicolumn{1}{c}{(3)}         &\multicolumn{1}{c}{(4)}         &\multicolumn{1}{c}{(5)}         &\multicolumn{1}{c}{(6)}      \\
\hline" if row == -1;
insobs 1;
replace row = 100 if row == .;
replace v1_1 = "\hline\hline
\end{tabular}
}" if row == 100;
sort row;
order v1_1 v2_1 v3_1 v4_1 v5_1 v6_1 v3_2 ;
replace v3_2 = v3_2+"\\" if row>0 & row<100;
tostring row, replace;
clean_quotes;
clean_row_names;
destring row, replace;
replace v2_1 = "&"+v2_1 if row >0 & row<100;
replace v3_1 = "&"+v3_1 if row >0 & row<100;
replace v4_1 = "&"+v4_1 if row >0 & row<100;
replace v5_1 = "&"+v5_1 if row >0 & row<100;
replace v6_1 = "&"+v6_1 if row >0 & row<100;
replace v3_2 = "&"+v3_2 if row >0 & row<100;
drop row;
outfile using gather_R1/main_table_highAOD.tex, noq replace;
export delim using gather_R1/main_table_highAOD.csv, novarnames replace;
erase gather_R1/output_table.dta;
clear;

**MW: move output;
copy "$gc_data/data_analysis/gather_R1/main_table_highAOD.tex" "$tables_mw/table4_lowaod.tex", public replace;


** Table 5: LONG RUN EFFECTS: HIGH AOD CITIES ONLY **;
global input_tables 	"Table_s6_10km_18BE_to_48AE_12b_fs
			Table_s62_10km_18BE_to_48AE_12b_fs
			Table_s6_10km_18BE_to_36AE_12b_fs
			Table_s62_10km_18BE_to_36AE_12b_fs
			Table_s6_10km_18BE_to_24AE_12b_fs
			Table_s62_10km_18BE_to_24AE_12b_fs
			";

*gather up all the columns we want into one stata file;
clear;
local i=1;
foreach table of global input_tables {;
	display "in condense tables";
	display "output_event_study/tables/`table'.csv";
	local in "output_event_study/tables/`table'.csv";
	import delimited `in',  stringcols(_all);
	if `i'==1{;
		keep v1 v6;
		};
	if `i'==2 | `i' == 4 | `i' == 6{;
		keep v3;
		};
	if `i'==3 | `i' == 5{;
		keep v6;
		};
	rename v* v*_`i';
	gen row=_n;
	*fix so rows line up at end;
	replace row=cond((`i'==3|`i'==4)&_n>=8,row+2,row);
	replace row=cond((`i'==5|`i'==6)&_n>=6,row+4,row);
	if `i'==1{;
		save gather_R1/output_table,replace;
		};
	if `i'>1{;
		merge 1:1 row using gather_R1/output_table;
		drop _merge;
		sort row;
		save gather_R1/output_table,replace;
		};
	clear;
	local i = `i'+1;
	};
*organize for output to latex;
use gather_R1/output_table,clear;
drop if row>=22;
drop if (row==1);
drop if row == 16;
insobs 1;
replace row = -1 if row == .;
replace v1_1 = "{
\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}
\begin{tabular}{l*{6}{c}}
\hline\hline
        &\multicolumn{1}{c}{(1)}         &\multicolumn{1}{c}{(2)}         &\multicolumn{1}{c}{(3)}         &\multicolumn{1}{c}{(4)}         &\multicolumn{1}{c}{(5)}         &\multicolumn{1}{c}{(6)}         \\
\hline Panel a. \\" if row == -1;
sort row;
order v1_1 v6_5 v3_6 v6_3 v3_4 v6_1 v3_2;
sort row;
replace v3_2 = v3_2+"\\" if row >0 & row <100;
tostring row, replace;
clean_quotes;
clean_row_names;
destring row, replace;
replace v6_1 = "&"+v6_1 if row >0 & row<100;
replace v3_2 = "&"+v3_2 if row >0 & row<100;
replace v6_3 = "&"+v6_3 if row >0 & row<100;
replace v3_4 = "&"+v3_4 if row >0 & row<100;
replace v6_5 = "&"+v6_5 if row >0 & row<100;
replace v3_6 = "&"+v3_6 if row >0 & row<100;
replace v1_1 = "1-12 months post" if v1_1 == "post";
replace v1_1 = "13-24 months post" if v1_1 == "plus2";
replace v1_1 = "25-36 months post" if v1_1 == "plus3";
replace v1_1 = "37-48 months post" if v1_1 == "plus4";
save gather_R1/output_table,replace;

** Table 5: Panel B;
global input_tables 	"Table_s6_10km_18BE_to_48AE_48b_fs
			Table_s62_10km_18BE_to_48AE_48b_fs
			Table_s6_10km_18BE_to_36AE_36b_fs
			Table_s62_10km_18BE_to_36AE_36b_fs
			Table_s6_10km_18BE_to_24AE_24b_fs
			Table_s62_10km_18BE_to_24AE_24b_fs
			";

*gather up all the columns we want into one stata file;
clear;
local i=1;
foreach table of global input_tables {;
	display "in condense tables";
	display "output_event_study/tables/`table'.csv";
	local in "output_event_study/tables/`table'.csv";
	import delimited `in',  stringcols(_all);
	if `i'==1{;
		keep v1 v6;
		};
	if `i'==2 | `i' == 4 | `i' == 6{;
		keep v3;
		};
	if `i'==3 | `i' == 5{;
		keep v6;
		};
	rename v* v*_`i';
	gen row=_n;
	if `i'==1{;
		save gather_R1/output_table_part2,replace;
		};
	if `i'>1{;
		merge 1:1 row using gather_R1/output_table_part2;
		drop _merge;
		sort row;
		save gather_R1/output_table_part2,replace;
		};
	clear;
	local i = `i'+1;
	};
*organize for output to latex;
use gather_R1/output_table_part2,clear;
drop if row>=11;
drop if (row==1);
drop if row>=4 & row<=9;
insobs 1;
replace row = -1 if row == .;
replace v1_1 = "\hline Panel b. \\" if row == -1;
insobs 1;
replace row = 100 if row == .;
replace v1_1 = "\hline\hline
\end{tabular}
}" if row == 100;
sort row;
order v1_1 v6_5 v3_6 v6_3 v3_4 v6_1 v3_2;
sort row;
replace v3_2 = v3_2+"\\" if row >0 & row <100;
tostring row, replace;
clean_quotes;
clean_row_names;
destring row, replace;
replace v6_1 = "&"+v6_1 if row >0 & row<100;
replace v3_2 = "&"+v3_2 if row >0 & row<100;
replace v6_3 = "&"+v6_3 if row >0 & row<100;
replace v3_4 = "&"+v3_4 if row >0 & row<100;
replace v6_5 = "&"+v6_5 if row >0 & row<100;
replace v3_6 = "&"+v3_6 if row >0 & row<100;
replace v1_1 = "average post" if v1_1 == "post";
replace row = row+1000;
save gather_R1/output_table_part2,replace;
use gather_R1/output_table,clear;
append using gather_R1/output_table_part2;
drop row;
outfile using gather_R1/long_run.tex, noq replace;
export delim using gather_R1/long_run.csv, replace;
erase gather_R1/output_table.dta;
erase gather_R1/output_table_part2.dta;

**MW: move output;
copy "$gc_data/data_analysis/gather_R1/long_run.tex" "$tables_mw/table5_lowaod.tex", public replace;


** SPATIAL DECAY: HIGH AOD CITIES ONLY **;
/*
(i)	(29 events, 29 cities): Table_s6_decay_18BE_to_18AE_18b_fs
Column 4 measures AOD in 10km disk
Column 5 measures AOD in 20-25km donut
Column 6 measures AOD in 25-50km donut

(ii)	(29 events, 500 cities): Table_s62_decay_18BE_to_18AE_18b_fs
Column 4 measures AOD in 10km disk
Column 5 measures AOD in 20-25km donut
Column 6 measures AOD in 25-50km donut
*/;
global input_tables 	"
			Table_s62_10km_18BE_to_18AE_18b_fs
			Table_s62_decay_18BE_to_18AE_18b_fs
			Table_s6_10km_18BE_to_18AE_18b_fs
			Table_s6_decay_18BE_to_18AE_18b_fs
			";
*gather up all the columns we want into one stata file;
clear;
local i=1;
foreach table of global input_tables {;
	display "in condense tables";
	display "output_event_study/tables/`table'.csv";
	local in "output_event_study/tables/`table'.csv";
	import delimited `in',  stringcols(_all);
	if `i'==1{;
		keep v1 v3;
		};
	if `i'==2{;
		keep v4 v5;
		};
	if `i'==3{;
		keep v6;
		};
	if `i'==4{;
		keep v4 v5;
		};
	rename v* v*_`i';
	gen row=_n;
	if `i'==1{;
		save gather_R1/output_table,replace;
		};
	if `i'>1{;
		merge 1:1 row using gather_R1/output_table;
		drop _merge;
		sort row;
		save gather_R1/output_table,replace;
		};
	clear;
	local i = `i'+1;
	};
*organize for output to latex;
use gather_R1/output_table,clear;
drop if row>=16;
drop if (row==1);
insobs 1;
replace row = -1 if row == .;
replace v1_1 = "{
\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}
\begin{tabular}{l*{6}{c}}
\hline\hline
        &\multicolumn{1}{c}{(1)}         &\multicolumn{1}{c}{(2)}         &\multicolumn{1}{c}{(3)}         &\multicolumn{1}{c}{(4)}         &\multicolumn{1}{c}{(5)}         &\multicolumn{1}{c}{(6)}     \\
\hline" if row == -1;
insobs 1;
replace row = 100 if row == .;
replace v1_1 = "\hline\hline
\end{tabular}
}" if row == 100;
sort row;
order v1_1 v6_3 v3_1 v4_4 v4_2 v5_4 v5_2;
sort row;
replace v5_2 = v5_2+"\\" if row >0 & row <100;
tostring row, replace;
clean_quotes;
clean_row_names;
destring row, replace;
replace v6_3 = "&"+v6_3 if row >0 & row<100;
replace v3_1 = "&"+v3_1 if row >0 & row<100;
replace v4_4 = "&"+v4_4 if row >0 & row<100;
replace v4_2 = "&"+v4_2 if row >0 & row<100;
replace v5_4 = "&"+v5_4 if row >0 & row<100;
replace v5_2 = "&"+v5_2 if row >0 & row<100;
drop row;
outfile using gather_R1/spatial_decay.tex, noq replace;
export delim using gather_R1/spatial_decay.csv, replace;
erase gather_R1/output_table.dta;
clear;

**MW: move output;
copy "$gc_data/data_analysis/gather_R1/spatial_decay.tex" "$tables_mw/table6_lowaod.tex", public replace;
