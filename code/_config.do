* Ensure Stata uses only local libraries and programs
tokenize `"$S_ADO"', parse(";")
while `"`1'"' != "" {
  if `"`1'"'!="BASE" cap adopath - `"`1'"'
  macro shift
}
adopath ++ "$root_mw/code/libraries/stata"

* load packages

* create directories
cap mkdir "$root_mw/output"
cap mkdir "$root_mw/output/figures"
cap mkdir "$root_mw/output/tables"
