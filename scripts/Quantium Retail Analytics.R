##########################
# Quantium Retail Analytics 
# Author: Bhavya Pandya
##########################


# 1. LOAD PACKAGES

library(tidyverse)
library(readxl)
library(lubridate)
library(janitor)
library(skimr)
library(scales)
library(cluster)
library(factoextra)
library(data.table)
library(ggplot2)


# 2. CREATE OUTPUT FOLDERS

dir.create("outputs", showWarnings = FALSE)
dir.create("outputs/tables", showWarnings = FALSE)
dir.create("outputs/plots", showWarnings = FALSE)


# 3. LOAD EXCEL FILE
# -----------------------------
data_path <- "data/Online Retail.xlsx"   # <-- YOUR EXCEL PATH

retail <- read_excel(data_path) %>%
  clean_names()

glimpse(retail)
skim(retail)

# -----------------------------
# 4. CLEAN DATA
# -----------------------------
retail_clean <- retail %>%
  filter(!is.na(customer_id)) %>%
  filter(quantity > 0) %>%
  filter(unit_price > 0) %>%
  mutate(
    invoice_date = as.POSIXct(invoice_date),
    total_price = quantity * unit_price
  ) %>%
  filter(!str_starts(invoice_no, "C"))

# -----------------------------
# 5. SUMMARY TABLE
# -----------------------------
summary_table <- retail_clean %>%
  summarise(
    total_transactions = n_distinct(invoice_no),
    total_customers = n_distinct(customer_id),
    total_products = n_distinct(stock_code),
    total_revenue = sum(total_price)
  )

write.csv(summary_table, "outputs/tables/summary_table.csv", row.names = FALSE)

# -----------------------------
# 6. TOP PRODUCTS
# -----------------------------
top_products <- retail_clean %>%
  group_by(description) %>%
  summarise(
    qty = sum(quantity),
    total_sales = sum(total_price)
  ) %>%
  arrange(desc(total_sales)) %>%
  slice(1:10)

write.csv(top_products, "outputs/tables/top_products.csv", row.names = FALSE)

# -----------------------------
# 7. TOP CUSTOMERS
# -----------------------------
top_customers <- retail_clean %>%
  group_by(customer_id) %>%
  summarise(
    total_spent = sum(total_price),
    transactions = n_distinct(invoice_no)
  ) %>%
  arrange(desc(total_spent)) %>%
  slice(1:10)

write.csv(top_customers, "outputs/tables/top_customers.csv", row.names = FALSE)

# -----------------------------
# 8. MONTHLY REVENUE TREND + PRINT
# -----------------------------
monthly_sales <- retail_clean %>%
  mutate(month = floor_date(invoice_date, "month")) %>%
  group_by(month) %>%
  summarise(total_sales = sum(total_price))

p1 <- ggplot(monthly_sales, aes(x = month, y = total_sales)) +
  geom_line(size = 1.2, color = "blue") +
  scale_y_continuous(labels = dollar) +
  labs(
    title = "Monthly Revenue Trend",
    x = "Month",
    y = "Revenue"
  ) +
  theme_minimal(base_size = 14)

print(p1)
ggsave("outputs/plots/monthly_revenue_trend.png", p1, width = 8, height = 4)

# -----------------------------
# 9. RFM ANALYSIS + PRINT
# -----------------------------
rfm <- retail_clean %>%
  group_by(customer_id) %>%
  summarise(
    recency = as.numeric(difftime(max(invoice_date), min(invoice_date), units = "days")),
    frequency = n_distinct(invoice_no),
    monetary = sum(total_price)
  )

rfm_scaled <- scale(rfm[, 2:4])

set.seed(123)
k3 <- kmeans(rfm_scaled, centers = 3, nstart = 20)
rfm$cluster <- k3$cluster

write.csv(rfm, "outputs/tables/rfm_segments.csv", row.names = FALSE)

p2 <- fviz_cluster(k3, data = rfm_scaled,
                   geom = "point",
                   ellipse.type = "norm",
                   ggtheme = theme_minimal())

print(p2)
ggsave("outputs/plots/rfm_clusters.png", p2, width = 7, height = 5)

# -----------------------------
# 10. PRODUCT CLUSTERING + PRINT
# -----------------------------
product_sales <- retail_clean %>%
  group_by(stock_code) %>%
  summarise(
    total_qty = sum(quantity),
    total_rev = sum(total_price)
  )

product_scaled <- scale(product_sales[,2:3])

set.seed(100)
pk3 <- kmeans(product_scaled, centers = 3, nstart = 20)
product_sales$cluster <- pk3$cluster

write.csv(product_sales, "outputs/tables/product_clusters.csv", row.names = FALSE)

p3 <- fviz_cluster(pk3, data = product_scaled,
                   geom = "point",
                   ellipse.type = "norm",
                   ggtheme = theme_minimal())

print(p3)
ggsave("outputs/plots/product_clusters.png", p3, width = 7, height = 5)


cat("\n-------- ANALYSIS COMPLETE --------\n")
cat("Tables saved to: outputs/tables\n")
cat("Plots saved to: outputs/plots\n")
cat("-------\n")
