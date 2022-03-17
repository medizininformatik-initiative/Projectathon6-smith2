#load/install a packages
source("install_R_packages.R")

###Source config information
#source config
if(file.exists("config.R")&&!dir.exists("config.R")){
  source("config.R")
}else{
  source("config.R.default")  
}

date <- as.Date(date)

#create directory for results
if(!dir.exists("Ergebnisse")){dir.create("Ergebnisse")}


#If needed disable peer verification
if(!ssl_verify_peer){httr::set_config(httr::config(ssl_verifypeer = 0L))}

#remove trailing slashes from endpoint
base <- if(grepl("/$", base)){strtrim(base, width = nchar(base)-1)}else{base}


brackets = c("[", "]")
sep = " || "

### Get all Consent-Resources ###
consent_request <- fhir_url(url = base, resource = "Consent" )
consent_bundles <- fhir_search(request = consent_request,
                               username = username,
                               password = password,
                               token = token,
                               verbose = 0)

#Extract relevant information
consent_description <- fhir_table_description("Consent",
                                              cols = c(patient = "patient/reference",
                                                       provision.display = "provision/provision/code/coding/display",
                                                       provision.code = "provision/provision/code/coding/code",
                                                       provision.start = "provision/provision/period/start",
                                                       provision.end = "provision/provision/period/end"))

consent <- fhir_crack(bundles = consent_bundles,
                      design = consent_description,
                      brackets = brackets,
                      sep = sep,
                      data.table = TRUE)

consent <- fhir_melt(indexed_data_frame = consent,
                     columns = fhir_common_columns(consent, "provision"),
                     brackets = brackets, 
                     sep = sep,
                     all_columns = TRUE
)

consent <- fhir_melt(indexed_data_frame = consent,
                     columns = fhir_common_columns(consent, "provision"),
                     brackets = brackets, 
                     sep = sep,
                     all_columns = TRUE
)

#remove indices
consent <- fhir_rm_indices(consent, brackets = brackets)

#keep only provisions chosen in config
consent <- consent[provision.code %in% c(provision_erheben, provision_nutzen)]


#Filter for consents that allow "nutzen" at time of analysis
consent[,c("provision.start", "provision.end"):=.(as.Date(provision.start), as.Date(provision.end))]
consent_erheben <- consent[provision.code == provision_erheben]
consent_nutzen <- consent[provision.code == provision_nutzen]

consent <- merge.data.table(x = consent_erheben, 
                         y = consent_nutzen[,.(provision.start, provision.end, provision.display, resource_identifier)],
                         by = "resource_identifier", 
                         all.x = TRUE,
                         all.y = FALSE,
                         suffixes = c("", ".nutzen"))

consent <- consent[date > provision.start.nutzen & date < provision.end.nutzen]

consent[,c("provision.start.nutzen", "provision.end.nutzen", "resource_identifier"):=NULL]

#for each Consent, find Encounters that overlap with "erheben" consent period and extract info
result <- data.table()

for(i in 1:nrow(consent)){
  
  #get encounters
  request <- fhir_url(url = base, 
                      resource = "Encounter",
                      parameters = c(subject = consent$patient[i],
                                     type = "einrichtungskontakt",
                                     date = paste0("ge", consent$provision.start[i]),
                                     date = paste0("le", consent$provision.end[i])
                                     )
                      )
  
  encounter_bundle <- fhir_search(request = request,
                                  username = username,
                                  password = password,
                                  token = token,
                                  verbose = 0)
  
  #extract relevant info
  encounter_description <- fhir_table_description("Encounter",
                                                  cols = c(Patient.id = "subject/reference",
                                                           Encounter.id = "id",
                                                           Encounter.identifier = "identifier/value",
                                                           Encounter.identifier.system = "identifier/system",
                                                           Encounter.start = "period/start", 
                                                           Encounter.end = "period/end"
                                                           )
                                                  )
  
  encounters <- fhir_crack(bundles = encounter_bundle,
                           design = encounter_description,
                           brackets = brackets,
                           sep = sep,
                           data.table = TRUE)
  
  #only keep identifier chosen in config
  encounters <- fhir_melt(indexed_data_frame =  encounters, 
                          columns = c("Encounter.identifier", "Encounter.identifier.system"),
                          brackets = brackets,
                          sep = sep, 
                          all_columns = TRUE)
  
  encounters <- fhir_rm_indices(encounters, brackets = brackets)
  encounters[, resource_identifier:=NULL]
  
  encounters <- encounters[Encounter.identifier.system==identifierSystem]
  encounters[,Encounter.identifier.system:=NULL]


  #add consent info
  encounters[, c("policy_erheben", "policy_nutzen") := .(consent[i]$provision.display, consent[i]$provision.display.nutzen)]
  encounters <- cbind(encounters, consent[i, .(provision.start, provision.end)]) 
  result <- rbind(result, encounters)
}

#save results
write.csv2(result, file = "Ergebnisse/Consented_Encounters.csv", row.names = FALSE)
