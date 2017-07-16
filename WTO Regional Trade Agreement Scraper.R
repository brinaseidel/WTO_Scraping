# WTO Regional Trade Agreement Scraper.R
# 5/24/2017

rm(list = ls())
setwd("/Users/brinaseidel/Documents/Work/Brookings/WTO Scraping/")

library(RSelenium)
library(stringr)

# ******************************
# Start the remote driver
# ******************************

# Create the server object (?)
selServ <- RSelenium::startServer(javaargs = c("-Dwebdriver.gecko.driver=\"/Users/brinaseidel/Documents/Work/Brookings/Scraping/geckodriver\""))

# Start the remote driver
rem_dr <- remoteDriver(port = 4445, browser="firefox", extraCapabilities = list(marionette = TRUE))
rem_dr$open()

# ******************************
# Create blank dataframe to store results
# ******************************

# Note: We don't know yet how many RTAs there will be, so we'll just create 2000 rows and delete the blank ones later
rtas <- data.frame(rta_name=character(2000), rta_type=character(2000), rta_status=character(2000),
                       sign_date=character(2000), entry_date=character(2000), 
                       current_countries=character(2000), orig_countries=character(2000), stringsAsFactors = FALSE)

# ******************************
# Navigate to WTO RTA database search page
# ******************************
rem_dr$navigate("https://rtais.wto.org/UI/PublicSearchByCr.aspx")
Sys.sleep(2) 
webElem <- rem_dr$findElement(using = "link text", "By criteria")
webElem$clickElement()
Sys.sleep(2) 

# ******************************
# Search for all RTAs (by selecting all possible agreement statuses)
# ******************************

# Check the box for all four possible agreement statuses
webElem <- rem_dr$findElement(using = "xpath", "//input[@id=\"ctl00_ContentPlaceHolder1_selStatus\"]")
webElem$clickElement()
for (i in 0:3) {
  status_xpath <- paste("//input[@id=\"ctl00_ContentPlaceHolder1_chkStatusList_", i, "\"]", sep="")
  webElem <- rem_dr$findElement(using = "xpath", status_xpath)
  webElem$clickElement()
}

# Click search button
webElem <- rem_dr$findElement(using = "id", "ctl00_ContentPlaceHolder1_btnSearch")
webElem$clickElement()

Sys.sleep(2) 

# ******************************
# Loop through all pages of results, clicking on the links to the details of the RTA, and saving the details
# ******************************

# Determine how many pages of results there are by checking the last row of the table
webElem <- rem_dr$findElement(using = "xpath", "//td[@colspan=7]")
last_row <- webElem$getElementAttribute("innerHTML")
# Count <td> tags, each of which contains a page number (number of tags = number of pages)
num_pages <- str_count(last_row, "<td>")

# Loop through all pages of results, clicking to go to the next one at the end of each page
row_num <- 0
for (i in 1:num_pages) {

  # Determine how many rows there in the table on this page (excluding header and footer row)
  webElem <- rem_dr$findElement(using = "xpath", "//table[@id=\"ctl00_ContentPlaceHolder1_grdRTAList\"]")
  table <- webElem$getElementAttribute("innerHTML")
  num_rows <- str_count(table, "<tr") - 2
  
  # Loop through all rows of the table on this page, each of which contains the link to more details on an RTA
  for (j in 1:(num_rows-1)) {
    
    link_xpath <- paste("//tr[@class=\"ProductsGridViewRow\"][", j, "]/td/a", sep="")
    webElem <- rem_dr$findElement(using = "xpath", link_xpath)
    webElem$clickElement()
    Sys.sleep(1)
    
    # Collect information on this RTA, using a tryCatch statement for the first one in case the page took an unusally long time to load
    row_num <- row_num + 1
    # RTA name (using tryCatch -- this will capture the error if the page has not loaded yet and thus the element can't be found, wait three seconds for the page to load, then try again)
    webElem <- tryCatch({
      rem_dr$findElement(using = "id", "ctl00_ContentPlaceHolder1_showRelAggreement_RTAIdCardTabContainer_BasicInfoTbPanel_txtEngAgrName")
    },
    error=function(err) {
      message("Error locating the RTA name, probably because page did not load quickly enough - wait three seconds and try again")
      Sys.sleep(3)
      return(rem_dr$findElement(using = "id", "ctl00_ContentPlaceHolder1_showRelAggreement_RTAIdCardTabContainer_BasicInfoTbPanel_txtEngAgrName"))
    })
    rtas$rta_name[row_num] <- webElem$getElementAttribute("innerHTML")[[1]][1]
    print(rtas$rta_name[row_num])
    # RTA type (goods, services, goods and services)
    webElem <- rem_dr$findElement(using = "id", "ctl00_ContentPlaceHolder1_showRelAggreement_RTAIdCardTabContainer_BasicInfoTbPanel_selCoverage")
    rtas$rta_type[row_num] <- webElem$getElementAttribute("innerHTML")[[1]][1]
    # RTA status (in force, inactive, etc.)
    webElem <- rem_dr$findElement(using = "id", "ctl00_ContentPlaceHolder1_showRelAggreement_RTAIdCardTabContainer_BasicInfoTbPanel_selStatus")
    rtas$rta_status[row_num] <- webElem$getElementAttribute("innerHTML")[[1]][1]
    # Signing date
    webElem <- rem_dr$findElement(using = "id", "ctl00_ContentPlaceHolder1_showRelAggreement_RTAIdCardTabContainer_BasicInfoTbPanel_txtGSD")
    rtas$sign_date[row_num] <- webElem$getElementAttribute("innerHTML")[[1]][1]
    # Date of entry into force
    webElem <- rem_dr$findElement(using = "id", "ctl00_ContentPlaceHolder1_showRelAggreement_RTAIdCardTabContainer_BasicInfoTbPanel_txtDOE")
    rtas$entry_date[row_num] <- webElem$getElementAttribute("innerHTML")[[1]][1]    
    # Current signatories
    webElem <- rem_dr$findElement(using = "id", "ctl00_ContentPlaceHolder1_showRelAggreement_RTAIdCardTabContainer_BasicInfoTbPanel_lbltxtCurrSign")
    rtas$current_countries[row_num] <- webElem$getElementAttribute("innerHTML")[[1]][1]    
    # Original signatories
    webElem <- rem_dr$findElement(using = "id", "ctl00_ContentPlaceHolder1_showRelAggreement_RTAIdCardTabContainer_BasicInfoTbPanel_lbltxtOrigSign")
    rtas$orig_countries[row_num] <- webElem$getElementAttribute("innerHTML")[[1]][1]    
    
    # Navigate back to table with list of results
    rem_dr$goBack()
    Sys.sleep(1.5)
    
  }
  
  # Navigate to the next page
  if (i < num_pages) {
    next_page <- as.character(i+1)
    webElem <- rem_dr$findElement(using = "link text", next_page)
    webElem$clickElement()
    Sys.sleep(2.5)
  }

}


# ******************************
# Export results
# ******************************
write.csv(rtas, file="Output Data/WTO Regional Trade Agreements.csv", row.names = FALSE)