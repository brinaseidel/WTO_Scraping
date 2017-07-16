# Scraping WTO Disputes.R
# 5/15/2017

rm(list = ls())
setwd(" xxx Change Directory xxx ")

library(RSelenium)

# ******************************
# Start the remote driver
# ******************************

# Create the server object (?)
selServ <- RSelenium::startServer(javaargs = c("-Dwebdriver.gecko.driver=\" xxx Change Directory xxx \geckodriver\""))

# Start the remote driver
rem_dr <- remoteDriver(port = 4445, browser="firefox", extraCapabilities = list(marionette = TRUE))
rem_dr$open()

# Navigate to WTO disputes page
rem_dr$navigate("https://www.wto.org/english/tratop_e/dispu_e/dispu_status_e.htm")
Sys.sleep(4) 

# ******************************
# Get ID of most recent dispute, so that we know how many disputes there are total
# ******************************
webElem <- rem_dr$findElement(using = "xpath", "//ul[@id=\"cases_list\"]/li/h3/a")
num_disputes <- as.numeric(webElem$getElementAttribute("id"))
print(paste("Number of Disputes: ", num_disputes))

# ******************************
# Create blank dataframe to store results
# ******************************
disputes <- data.frame(ds_num=integer(num_disputes), ds_name=character(num_disputes), 
                       defendant=character(num_disputes), complainant=character(num_disputes), date=character(num_disputes), 
                       status=character(num_disputes), stringsAsFactors = FALSE)

# ******************************
# Loop through all disputes and collect information
# ******************************

# Loop through all dispute numbers
for (i in 1:num_disputes) {
  
  # Store dispute number
  disputes$ds_num[i] <- i 
  
  # Get dispute name from the header node
  webElem <- rem_dr$findElement(using = "xpath", paste("//ul[@id=\"cases_list\"]/li/h3/a[@id=", i, "]", sep=""))
  header_info <- webElem$getElementAttribute("innerHTML")
  header_info <- trimws(gsub("^.*</small>", "", header_info))
  # Clean the result into the name
  header_info <- strsplit(header_info, "—")
  # Store dispute name
  disputes$defendant[i] <- trimws(header_info[[1]][1])
  disputes$ds_name[i] <- trimws(header_info[[1]][2])
  
  # Get dispute details from the paragraph node
  webElem <- rem_dr$findElement(using = "xpath", paste("//ul[@id=\"cases_list\"]/li[h3[a[@id=\"", i, "\"]]]/p", sep=""))
  details <- as.character(webElem$getElementAttribute("innerHTML"))
  # Clean details into a list of complainant, date consultations requested, and current status
  details <- strsplit(details, "<br>")
  details <- lapply(details, function(x) gsub("&nbsp;", "", x))
  details <- lapply(details, function(x) trimws(gsub("^.*:", "", x)))
  # Store complainant, date consultations requested, and current status
  disputes$complainant[i] <- details[[1]][1]
  disputes$date[i] <- details[[1]][2]
  disputes$status[i] <- details[[1]][3]
}

# ******************************
# Export results
# ******************************
write.csv(disputes, file="Output Data/WTO Disputes.csv", row.names = FALSE)
