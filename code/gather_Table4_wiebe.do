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


*-------------------------------------------------------------------------------;
*-------------------------------------------------------------------------------;
*-------------------------------------------------------------------------------;
** MAIN RESULTS: HIGH AOD CITIES ONLY **;
*-------------------------------------------------------------------------------;
*-------------------------------------------------------------------------------;
*-------------------------------------------------------------------------------;

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
if "$type_mw" == "2001" {;
	copy "$gc_data/data_analysis/gather_R1/main_table_highAOD.tex" "$tables_mw/main_table_highAOD_aod$type_mw.tex", public replace;
};
if "$type_mw" == "40" {;
	copy "$gc_data/data_analysis/gather_R1/main_table_highAOD.tex" "$tables_mw/main_table_highAOD_p$type_mw.tex", public replace;
};
if "$type_mw" == "60" {;
	copy "$gc_data/data_analysis/gather_R1/main_table_highAOD.tex" "$tables_mw/main_table_highAOD_p$type_mw.tex", public replace;
};
