library(tidyverse)
library(lubridate) # For fixing dates
library(tseries)  # For ADF test
library(forecast) # The Gold Standard for ARIMA
library(zoo)      # For missing data interpolation



#------------ load the data


# feature contains temperature, humidity, etc 
features <- read.csv("D:/R for public health/Dengue outbreak forecasting/dengue_features_train.csv")


# labels contains the toatal cases
labels <- read.csv("D:/R for public health/Dengue outbreak forecasting/dengue_labels_train.csv")



#----------- Merging the data on basis of city and year to match the data 
#----- combined 2 seperate data sheets of features and labels into 1 

df_full <- left_join(features, labels, by = c("city", "year", "weekofyear"))

glimpse(df_full)



#------ Filtering for particular city like San Juan 

df_sj <- df_full %>%
  filter(city == "sj") %>%
  
  # convert the text date to real date object 
  mutate(week_start_date = ymd(week_start_date)) %>%
  select(week_start_date, total_cases, everything())


summary(df_sj)


#------------------- Filling missing value using interpolation 
# we apply na.approx() to all columns for climate to input approximate values of the missing cells 

df_sj_clean <- df_sj %>%
  mutate(across(5:ncol(.), ~ na.approx(., na.rm = FALSE))) %>%
  drop_na() #Drop the rows that cant be fixed

#Verify no Nas remain
sum(is.na(df_sj_clean))




# -------------- Plotting the Epidemic curve 

# 1. Create the base plot (Run this line first)
p <- ggplot(df_sj_clean, aes(x = week_start_date, y = total_cases))

# 2. Add the blue line (Run this line next)
p <- p + geom_line(color = "navyblue", size = 0.8)

# 3. Add the labels (Run this line next)
p <- p + labs(title = "Dengue Outbreaks in San Juan",
              x = "Date", 
              y = "Total Cases")

# 4. Add the theme (Run this line next)
p <- p + theme_minimal()

# 5. Finally, show the plot
print(p)




# Convert the total cases in the time series(ts) object 

ts_sj <- ts(df_sj_clean$total_cases, start = c(1990,18), frequency = 52)

print(class(ts_sj))



# Perform season decomposition of time series by loess (STL)

decomp <- stl(ts_sj, s.window = "period")

#----------- Plotting the decomposition 
autoplot(decomp)+ ggtitle("Time series decomposition of Dengue in San Juan") + theme_minimal()



#------------------ ADF test to test stability of the data 


adf_test <- adf.test(ts_sj)

print(adf_test)




#----------------- Preparation of ARIMA model 

train_data <- subset(ts_sj, end = length(ts_sj)-100)
test_data <- subset(ts_sj, start = length(ts_sj)-99)



#--------- Fit ARIMA model 
#------ 'seasonal = TRUE' tells R to look for that yearly heartbeat pattern 

fit_arima <- auto.arima(train_data, seasonal = TRUE)


#---- Summary of the model 

print(fit_arima)


#---------- Check for residuals  (errors)

checkresiduals(fit_arima)


# ---- Forecasting the next 100 weeks 

forecast_values <- forecast(fit_arima, h = 100)

#-------- Plotting forecast vs actual data

autoplot(forecast_values) + autolayer(test_data, series = "Actual Data", PI = FALSE) +
  ggtitle("ARIMA forecast of Dengue in San Juan") + xlab("Year") + ylab("Weekly Cases") + guides(colour = guide_legend(title = "Legend")) + theme_minimal()

#--------- Calculating accuracy (Mean absolute error)

accuracy(forecast_values, test_data)
