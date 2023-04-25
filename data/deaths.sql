
CREATE TABLE covid_db.covid_deaths(
iso_code TEXT,
continent TEXT,
location TEXT,
date TEXT,
population BIGINT,
total_cases BIGINT,
new_cases BIGINT,
new_cases_smoothed FLOAT,
total_deaths BIGINT,
new_deaths BIGINT,
new_deaths_smoothed FLOAT,
total_cases_per_million BIGINT,
new_cases_per_million BIGINT,
new_cases_smoothed_per_million BIGINT,
total_deaths_per_million BIGINT,
new_deaths_per_million BIGINT,
new_deaths_smoothed_per_million FLOAT,
reproduction_rate BIGINT,
icu_patients BIGINT,
icu_patients_per_million BIGINT,
hosp_patients BIGINT,
hosp_patients_per_million BIGINT,
weekly_icu_admissions BIGINT,
weekly_icu_admissions_per_million BIGINT,
weekly_hosp_admissions BIGINT,
weekly_hosp_admissions_per_million BIGINT
);

LOAD DATA LOCAL INFILE '/home/ubuntu/covid_deaths.csv' INTO TABLE covid_db.covid_deaths CHARACTER SET UTF8 FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\r\n' IGNORE 1 LINES;
