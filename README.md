This repository contains Stata .do files for my comment on "[Subways and Urban Air Pollution](https://www.aeaweb.org/articles?id=10.1257/pol.20190509)", Gendron-Carrier et al. (2022).

To combine my code with the data, first download this repository, then download the original [replication package](https://www.openicpsr.org/openicpsr/project/126401/version/V1/view) and extract the folders 'data/' and 'data_analysis/' to the directory 'data/GendronCarrier_etal_2020_replication/data_proccessing/'.
This requires signing up for an ICPSR account.

To rerun the analyses, run the file `run.do` using Stata (version 15). 
Note that you need to set the path in `run.do` on line 2, to define the location of the folder that contains this README.
Required Stata packages are included in 'code/libraries/stata/', so that the user does not have to download anything and the replication can be run offline.
The file `code/_config.do` tells Stata to load packages from this location.

Figures and tables are saved in 'output/'; that directory is created by `code/_config.do`.
It takes approximately 20-30 hours to run the code using Stata-SE. 
It helps to close web browsers to free up memory.