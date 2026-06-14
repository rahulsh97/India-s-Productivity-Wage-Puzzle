/*==============================================================================
  REPLICATION FILE FOR:
  "Productivity up, wages flat: India's manufacturing growth has
   stopped working for its workers"
  Rahul Shukla (International Growth Centre)
  Ideas for India, 2026

  Reproduces all descriptive statistics, robustness checks, and figures
  using the source workbook (ASI 2023-24 + ASUSE 2023-24, MoSPI).

  TO RUN:
    1. Place this file in the same folder as "productivity_wage_puzzle.xlsx".
    2. Set the working directory on line 30 below.
    3. Run the entire file.

  REQUIREMENTS:
    Stata 15 or later. No user-written packages required.
==============================================================================*/

clear all
set more off
version 15

*-- SET YOUR WORKING DIRECTORY HERE
*   Edit the path below to the folder that contains this .do file and
*   the productivity_wage_puzzle.xlsx workbook. Use forward slashes.
cd "INSERT/PATH/TO/THIS/REPOSITORY"   // e.g. "C:/Users/yourname/productivity-wage-puzzle"

cap mkdir "figures"
cap mkdir "logs"

log using "logs/analysis_log.smcl", replace

*==============================================================================
* SECTION 1 -- LOAD STATE-LEVEL DATA FROM SHEET1
*==============================================================================

*-- Sheet1 layout (verified against the source workbook):
*     Column C  = state/UT
*     Column H  = GVA/Worker (ASUSE)  -- informal mfg GVA per worker (Rs)
*     Column I  = GVA/Worker (ASI)    -- formal mfg GVA per worker (Rs)
*     Column J  = Wages/worker (ASI)  -- formal mfg wage per worker (Rs)
*   The headers contain slashes/parentheses that Stata's firstrow mangles
*   inconsistently across versions. We import the specific columns via
*   cellrange and rename by position instead.

*-- Import the 8 columns we need (C through J), rows 2 through 38.
*   Sheet1 has 36 states/UTs + "All India" = 37 data rows below the header,
*   so the data range is C2:J38. If the workbook is updated with more states,
*   extend the end row accordingly.
import excel "productivity_wage_puzzle.xlsx", ///
    sheet("Sheet1") cellrange(C2:J38) clear
describe
*-- Stata named the 8 imported columns A..H. Rename the four we need:
rename C state
rename H asuse_gva
rename I asi_gva
rename J asi_wage
keep state asuse_gva asi_gva asi_wage

*-- Drop blank rows and rows missing formal-sector data
drop if missing(state)
drop if missing(asi_gva) | missing(asi_wage)

count
display "State rows with complete formal data: " r(N)

*-- Flag All-India
gen byte is_all_india = (state == "All India")

*-- Derived variables
gen wage_share      = 100 * asi_wage / asi_gva
gen log_asi_gva     = ln(asi_gva)
gen log_asi_wage    = ln(asi_wage)
gen log_asuse_gva   = ln(asuse_gva)
gen wage_to_asuse   = asi_wage / asuse_gva

label variable asi_gva       "Formal GVA per worker (Rs)"
label variable asi_wage      "Formal wage per worker (Rs)"
label variable asuse_gva     "Informal GVA per worker (Rs)"
label variable wage_share    "Wage share of formal GVA (%)"
label variable wage_to_asuse "Formal wage / Informal GVA"

*-- State subsamples used in the article
gen byte major_state = ///
    inlist(state, "Andhra Pradesh","Assam","Bihar","Chhattisgarh","Delhi", ///
                  "Goa","Gujarat","Haryana") ///
  | inlist(state, "Himachal Pradesh","Jharkhand","Karnataka","Kerala", ///
                  "Madhya Pradesh","Maharashtra","Odisha","Punjab") ///
  | inlist(state, "Rajasthan","Tamil Nadu","Telangana","Uttar Pradesh", ///
                  "Uttarakhand","West Bengal")

gen byte extractive = ///
    inlist(state, "Jharkhand","Odisha","Goa","Chhattisgarh","Sikkim", ///
                  "Himachal Pradesh","Madhya Pradesh","Meghalaya")

gen byte major_non_extractive = major_state & !extractive

tempfile state_data
save "state_data.dta", replace

*==============================================================================
* SECTION 2 -- DESCRIPTIVE STATISTICS
*==============================================================================

display _n(2) "=== Section 2: Descriptive Statistics ===" _n

display _n "All-India figures (2023-24):"
list state asi_gva asi_wage asuse_gva wage_share if is_all_india, ///
    abbreviate(16) noobs clean

display _n "Summary across all states (excluding All India):"
summarize asi_gva asi_wage asuse_gva wage_share if !is_all_india, detail

display _n "Summary across 22 major states/UTs:"
summarize asi_gva asi_wage wage_share if major_state, detail

display _n "Summary across 16 major non-extractive states:"
summarize asi_gva asi_wage wage_share if major_non_extractive, detail

*==============================================================================
* SECTION 3 -- CORRELATIONS AND ELASTICITIES
*==============================================================================

display _n(2) "=== Section 3: Correlations ===" _n

display _n "Core finding: log(formal GVA per worker) vs wage share"
display "  All states excluding All India:"
pwcorr log_asi_gva wage_share if !is_all_india, sig star(0.05)

display "  22 major states/UTs (article's main sample):"
pwcorr log_asi_gva wage_share if major_state, sig star(0.05)

display "  16 major non-extractive states (robustness):"
pwcorr log_asi_gva wage_share if major_non_extractive, sig star(0.05)

display _n "Spearman rank correlation (robust to outliers):"
spearman log_asi_gva wage_share if major_state
spearman log_asi_gva wage_share if major_non_extractive

display _n "Log-log elasticity: d(log wage) / d(log productivity):"
regress log_asi_wage log_asi_gva if major_state, robust

display _n "Same regression within non-extractive states:"
regress log_asi_wage log_asi_gva if major_non_extractive, robust

display _n "OLS slope: wage share on log(GVA/worker)"
display "  Full 22-state sample:"
regress wage_share log_asi_gva if major_state, robust
scalar slope_full = _b[log_asi_gva]
scalar r_full = sign(_b[log_asi_gva]) * sqrt(e(r2))

display "  16 non-extractive states:"
regress wage_share log_asi_gva if major_non_extractive, robust
scalar slope_nonx = _b[log_asi_gva]
scalar r_nonx = sign(_b[log_asi_gva]) * sqrt(e(r2))

display _n "Summary of fit-line coefficients used in Figure 2:"
display "  All 22 major states:    slope = " %6.2f slope_full "   r = " %5.2f r_full
display "  16 non-extractive:      slope = " %6.2f slope_nonx "   r = " %5.2f r_nonx

*==============================================================================
* SECTION 4 -- TOP-5 vs BOTTOM-5 NON-EXTRACTIVE STATES
*==============================================================================

display _n(2) "=== Section 4: Top-5 and Bottom-5 among non-extractive states ===" _n

preserve
    keep if major_non_extractive
    gsort -asi_gva
    gen rank = _n

    display _n "Top 5 non-extractive states by formal productivity:"
    list rank state asi_gva asi_wage wage_share if rank <= 5, ///
         abbreviate(18) noobs clean

    display _n "Bottom 5 non-extractive states by formal productivity:"
    list rank state asi_gva asi_wage wage_share if rank >= _N - 4, ///
         abbreviate(18) noobs clean

    gen byte top5    = (rank <= 5)
    gen byte bottom5 = (rank >= _N - 4)

    display _n "Group averages:"
    summarize asi_gva wage_share if top5
    summarize asi_gva wage_share if bottom5
restore

*==============================================================================
* SECTION 5 -- FIGURE 1: TIME SERIES FROM SHEET3
*==============================================================================

display _n(2) "=== Section 5: Figure 1 ===" _n

*-- Sheet3 layout (verified against the source workbook):
*     Column B = year label (e.g. "2023-24")
*     Column C = state ("All India" for national series)
*     Column M = GVA/worker (nominal Rs per worker)
*   Columns K and L are duplicate "GVA" headers, so we use cellrange and
*   rename by position to avoid name-conflict errors.

preserve
    import excel "productivity_wage_puzzle.xlsx", ///
        sheet("Sheet3") cellrange(B2:M35) clear

    *-- cellrange imports 12 columns (B..M). Stata names them A..L.
   rename B year_str
rename C state_ts
rename M gva_per_worker_ts
    keep year_str state_ts gva_per_worker_ts

    *-- Ensure year_str is a string
    capture tostring year_str, replace force

    keep if state_ts == "All India"
    drop if missing(gva_per_worker_ts) | missing(year_str)

    gen year_num = real(substr(year_str, 1, 4))
    drop if missing(year_num)

    gen gva_lakh = gva_per_worker_ts / 100000

    sort year_num
    list year_str year_num gva_lakh, noobs

    count
    display "Time series observations: " r(N)

    twoway ///
        (connected gva_lakh year_num, ///
            lcolor("33 102 172") lwidth(medthick) ///
            mcolor("33 102 172") msymbol(O) msize(medium)) ///
        , ///
        title("Figure 1. Formal manufacturing productivity has more than doubled in 15 years", ///
              size(small) color(black)) ///
        ytitle("GVA per worker (Rs lakh, nominal)", size(small)) ///
        xtitle("Year", size(small)) ///
        xlabel(2008(1)2023, angle(45) labsize(vsmall)) ///
        ylabel(0(2)16, angle(0) labsize(small) grid) ///
        graphregion(color(white)) bgcolor(white) ///
        note("Source: Calculations from ASI Time Series Data (MoSPI). Nominal prices.", ///
             size(vsmall))

    graph export "figures/figure1_productivity_timeseries.png", ///
        width(1600) replace

    display "Figure 1 saved to figures/figure1_productivity_timeseries.png"
restore

use "state_data.dta", clear

*==============================================================================
* SECTION 6 -- FIGURE 2: WAGE SHARE vs PRODUCTIVITY
*==============================================================================

display _n(2) "=== Section 6: Figure 2 ===" _n

preserve
    keep if major_state

    gen log_gva_lakh = ln(asi_gva / 100000)

    regress wage_share log_gva_lakh
    predict yhat_full
    regress wage_share log_gva_lakh if major_non_extractive
    predict yhat_nonx

    local ai_ws = 13.7

    twoway ///
        (scatter wage_share log_gva_lakh if !extractive, ///
            mcolor("178 24 43") msymbol(O) msize(medlarge) mlcolor(white)) ///
        (scatter wage_share log_gva_lakh if extractive, ///
            mcolor("67 147 195") msymbol(S) msize(medlarge) mlcolor(white)) ///
        (line yhat_full log_gva_lakh, sort lpattern(dash) lcolor(black) lwidth(medium)) ///
        (line yhat_nonx log_gva_lakh if major_non_extractive, sort ///
            lpattern(solid) lcolor("178 24 43") lwidth(medthick)) ///
        , ///
        title("Figure 2. Higher-productivity states have lower wage shares" ///
              "(pattern holds after excluding capital-intensive extractive states)", ///
              size(small) color(black)) ///
        ytitle("Formal wage share of GVA (%)", size(small)) ///
        xtitle("Formal GVA per worker (Rs lakh, log scale)", size(small)) ///
        xlabel(`=ln(5)' "Rs 5L" `=ln(10)' "Rs 10L" `=ln(15)' "Rs 15L" ///
               `=ln(20)' "Rs 20L" `=ln(25)' "Rs 25L" `=ln(30)' "Rs 30L", ///
               labsize(small)) ///
        ylabel(0(5)25, angle(0) labsize(small) grid) ///
        yline(`ai_ws', lpattern(dot) lcolor(gs8)) ///
        legend(order( ///
            1 "Diversified / labour-intensive" ///
            2 "Extractive / capital-intensive-dominant" ///
            3 "Fit: all 22 states" ///
            4 "Fit: 16 non-extractive states") ///
            size(vsmall) position(1) ring(0) cols(1) region(lcolor(black))) ///
        graphregion(color(white)) bgcolor(white) ///
        note("Source:  Calculations from ASI 2023-24 (MoSPI). States with" ///
             "substantial ASI manufacturing activity only; Sikkim and tiny UTs excluded." ///
             "Dotted horizontal line shows the All-India wage share of 13.7%.", ///
             size(vsmall))

    graph export "figures/figure2_wageshare_vs_productivity.png", ///
        width(1800) replace
restore

display "Figure 2 saved to figures/figure2_wageshare_vs_productivity.png"

*==============================================================================
* SECTION 7 -- FIGURE 3: TOP-5 vs BOTTOM-5
*==============================================================================

display _n(2) "=== Section 7: Figure 3 ===" _n

preserve
    keep if major_non_extractive
    gsort -asi_gva
    gen rank = _n
    gen byte top5    = (rank <= 5)
    gen byte bottom5 = (rank >= _N - 4)
    keep if top5 | bottom5

    gen gva_lakh = asi_gva / 100000

    gsort -asi_gva
    gen disp_order = _n

    levelsof disp_order, local(orders)
    foreach v of local orders {
        local sname = state[`v']
        label define disp_lbl `v' "`sname'", add
    }
    label values disp_order disp_lbl

    gen byte grp = cond(top5, 1, 2)
    label define grplbl 1 "Top 5" 2 "Bottom 5"
    label values grp grplbl

    graph hbar (asis) gva_lakh, over(grp) over(disp_order, ///
            sort(disp_order) descending label(labsize(small))) ///
        asyvars ///
        bar(1, color("178 24 43")) ///
        bar(2, color("67 147 195")) ///
        blabel(bar, format(%4.1f) size(vsmall)) ///
        ytitle("Formal GVA per worker (Rs lakh)", size(small)) ///
        ylabel(0(5)25, labsize(small)) ///
        title("A. Productivity", size(small)) ///
        graphregion(color(white)) bgcolor(white) ///
        legend(off) ///
        name(panel_a, replace)

    graph hbar (asis) wage_share, over(grp) over(disp_order, ///
            sort(disp_order) descending label(labsize(small))) ///
        asyvars ///
        bar(1, color("178 24 43")) ///
        bar(2, color("67 147 195")) ///
        blabel(bar, format(%4.1f) size(vsmall)) ///
        ytitle("Worker wage share of GVA (%)", size(small)) ///
        ylabel(0(5)25, labsize(small)) ///
        title("B. Wage share", size(small)) ///
        graphregion(color(white)) bgcolor(white) ///
        legend(off) ///
        name(panel_b, replace)

    summarize asi_gva if top5, meanonly
    local top_gva = r(mean) / 100000
    summarize wage_share if top5, meanonly
    local top_ws = r(mean)
    summarize asi_gva if bottom5, meanonly
    local bot_gva = r(mean) / 100000
    summarize wage_share if bottom5, meanonly
    local bot_ws = r(mean)
    local ratio  = `top_gva' / `bot_gva'

    local combine_title = "Figure 3. Top 5 vs bottom 5 diversified-manufacturing states: " + ///
        string(`ratio', "%3.1f") + "x productivity, wage share " + ///
        string(`top_ws', "%3.0f") + "% vs " + string(`bot_ws', "%3.0f") + "%"

    graph combine panel_a panel_b, ///
        cols(2) ///
        title("`combine_title'", size(small)) ///
        graphregion(color(white)) ///
        note("Source: Calculations from ASI 2023-24 (MoSPI). All ten states shown have" ///
             "diversified manufacturing bases spanning textiles, food processing, chemicals, engineering, and autos.", ///
             size(vsmall))

    graph export "figures/figure3_top5_vs_bottom5.png", ///
        width(1800) replace
restore

display "Figure 3 saved to figures/figure3_top5_vs_bottom5.png"

*==============================================================================
* SECTION 8 -- SUMMARY TABLE
*==============================================================================

display _n(2) "=== Section 8: Summary of key numbers ===" _n

display "Headline finding:"
display "  All-India formal wage share of GVA (2023-24):        13.7%"
display "  (Compare: Kapoor 2020 reports 22.2% in 2000-01, 14.3% in 2011-12)"

display _n "Cross-state correlation (log productivity, wage share):"
quietly pwcorr log_asi_gva wage_share if major_state
display "  22 major states:                  r = " %5.2f r(rho)
quietly pwcorr log_asi_gva wage_share if major_non_extractive
display "  16 non-extractive major states:   r = " %5.2f r(rho)
quietly pwcorr log_asi_gva wage_share if !is_all_india
display "  All states (excl. All India):     r = " %5.2f r(rho)

display _n "OLS slope (wage share on log productivity):"
quietly regress wage_share log_asi_gva if major_state
display "  22 major states:                  slope = " %5.2f _b[log_asi_gva]
quietly regress wage_share log_asi_gva if major_non_extractive
display "  16 non-extractive major states:   slope = " %5.2f _b[log_asi_gva]

display _n "Log-log elasticity of wages to productivity:"
quietly regress log_asi_wage log_asi_gva if major_state
display "  22 major states:                  elasticity = " %5.2f _b[log_asi_gva]
quietly regress log_asi_wage log_asi_gva if major_non_extractive
display "  16 non-extractive major states:   elasticity = " %5.2f _b[log_asi_gva]

display _n(2) "=== Analysis complete. See 'figures/' for outputs. ==="

log close
