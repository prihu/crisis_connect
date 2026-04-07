#!/bin/bash
# CrisisConnect - BigQuery Dataset Setup
# Creates the crisis_connect dataset and loads seed data

set -e

PROJECT_ID=$(gcloud config get-value project)
DATASET=crisis_connect
LOCATION=US

echo "=== CrisisConnect BigQuery Setup ==="
echo "Project: $PROJECT_ID"
echo "Dataset: $DATASET"

# Create dataset
echo "Creating dataset..."
bq mk --dataset --location=$LOCATION ${PROJECT_ID}:${DATASET} 2>/dev/null || echo "Dataset already exists"

# -------------------------------------------------------------------
# Table 1: disaster_alerts
# -------------------------------------------------------------------
echo "Creating disaster_alerts table..."
bq query --use_legacy_sql=false --project_id=$PROJECT_ID "
CREATE TABLE IF NOT EXISTS \`${PROJECT_ID}.${DATASET}.disaster_alerts\` (
    event_id STRING,
    event_type STRING,
    severity STRING,
    country STRING,
    region STRING,
    event_date DATE,
    affected_population INT64,
    deaths INT64,
    displaced INT64,
    response_time_hours FLOAT64,
    status STRING,
    latitude FLOAT64,
    longitude FLOAT64,
    description STRING
);
"

echo "Loading disaster_alerts data..."
bq query --use_legacy_sql=false --project_id=$PROJECT_ID "
INSERT INTO \`${PROJECT_ID}.${DATASET}.disaster_alerts\` VALUES
('GDACS-TC-2024-001', 'typhoon', 'red', 'Philippines', 'Luzon', '2024-11-15', 2500000, 45, 180000, 4.5, 'resolved', 14.5995, 120.9842, 'Super Typhoon Pepito makes landfall in Aurora province with sustained winds of 195 km/h'),
('GDACS-TC-2024-002', 'typhoon', 'orange', 'Philippines', 'Visayas', '2024-12-01', 800000, 12, 45000, 6.2, 'resolved', 11.0, 124.0, 'Tropical Storm Querubin brings heavy rainfall to central Visayas'),
('GDACS-EQ-2025-001', 'earthquake', 'red', 'Japan', 'Ishikawa', '2025-01-01', 350000, 230, 34000, 2.1, 'resolved', 37.5, 137.3, 'M7.5 earthquake strikes Noto Peninsula, Ishikawa Prefecture'),
('GDACS-FL-2025-001', 'flood', 'orange', 'India', 'Maharashtra', '2025-02-10', 1200000, 28, 95000, 8.3, 'resolved', 19.076, 72.877, 'Severe monsoon flooding in Mumbai metropolitan area'),
('GDACS-TS-2024-001', 'tsunami', 'red', 'Indonesia', 'Sulawesi', '2024-09-28', 600000, 89, 52000, 3.7, 'resolved', -1.43, 121.45, 'Tsunami triggered by M7.1 offshore earthquake hits Palu coast'),
('GDACS-CY-2025-001', 'cyclone', 'red', 'Australia', 'Queensland', '2025-03-15', 450000, 8, 28000, 5.1, 'active', -19.25, 146.8, 'Category 4 Cyclone approaching Townsville'),
('GDACS-FL-2025-002', 'flood', 'orange', 'Bangladesh', 'Dhaka', '2025-03-20', 3000000, 55, 210000, 12.5, 'active', 23.81, 90.41, 'Brahmaputra river flooding affects Dhaka division'),
('GDACS-EQ-2025-002', 'earthquake', 'orange', 'Nepal', 'Kathmandu', '2025-03-01', 500000, 15, 22000, 4.0, 'resolved', 27.7172, 85.324, 'M6.2 earthquake near Kathmandu Valley'),
('GDACS-TC-2025-001', 'typhoon', 'red', 'Philippines', 'Manila', '2025-04-02', 5000000, 0, 0, 0, 'active', 14.5995, 120.9842, 'Typhoon warning: Super Typhoon approaching Metro Manila, landfall expected in 48 hours'),
('GDACS-WF-2025-001', 'wildfire', 'orange', 'Australia', 'New South Wales', '2025-01-20', 200000, 3, 15000, 6.0, 'resolved', -33.87, 151.21, 'Bushfire emergency in Blue Mountains region west of Sydney'),
('GDACS-EQ-2025-003', 'earthquake', 'red', 'Taiwan', 'Hualien', '2025-02-15', 280000, 18, 12000, 1.8, 'resolved', 23.99, 121.60, 'M7.2 earthquake strikes eastern Taiwan near Hualien'),
('GDACS-FL-2025-003', 'flood', 'red', 'Vietnam', 'Hanoi', '2025-03-05', 1500000, 35, 88000, 9.2, 'resolved', 21.03, 105.85, 'Red River flooding submerges parts of Hanoi'),
('GDACS-CY-2025-002', 'cyclone', 'orange', 'Sri Lanka', 'Eastern Province', '2025-01-10', 350000, 11, 42000, 7.5, 'resolved', 7.87, 81.87, 'Cyclone Burevi makes landfall on eastern coast of Sri Lanka'),
('GDACS-EQ-2025-004', 'earthquake', 'orange', 'Indonesia', 'Java', '2025-03-28', 420000, 22, 18000, 5.5, 'active', -6.2, 106.8, 'M6.8 earthquake in western Java near Jakarta'),
('GDACS-TC-2025-002', 'typhoon', 'orange', 'Taiwan', 'Taipei', '2025-04-01', 650000, 5, 12000, 3.2, 'active', 25.03, 121.57, 'Typhoon approaching northern Taiwan with 130 km/h winds'),
('GDACS-FL-2025-004', 'flood', 'orange', 'Thailand', 'Bangkok', '2025-03-22', 800000, 8, 35000, 10.0, 'resolved', 13.75, 100.52, 'Chao Phraya river overflow floods parts of Bangkok'),
('GDACS-CY-2025-003', 'cyclone', 'red', 'Myanmar', 'Rakhine', '2025-02-20', 950000, 65, 120000, 15.0, 'resolved', 20.15, 92.87, 'Severe cyclone devastates Rakhine coastal communities'),
('GDACS-EQ-2025-005', 'earthquake', 'orange', 'New Zealand', 'Canterbury', '2025-01-28', 180000, 2, 5000, 2.5, 'resolved', -43.53, 172.64, 'M6.0 earthquake near Christchurch'),
('GDACS-FL-2025-005', 'flood', 'red', 'Pakistan', 'Sindh', '2025-03-10', 4200000, 120, 350000, 18.0, 'resolved', 25.39, 68.37, 'Indus river flooding displaces millions in Sindh province'),
('GDACS-TC-2025-003', 'typhoon', 'orange', 'South Korea', 'Jeju', '2025-03-30', 300000, 3, 8000, 4.0, 'active', 33.49, 126.53, 'Typhoon approaching Jeju Island with heavy rainfall');
"

# -------------------------------------------------------------------
# Table 2: community_demographics
# -------------------------------------------------------------------
echo "Creating community_demographics table..."
bq query --use_legacy_sql=false --project_id=$PROJECT_ID "
CREATE TABLE IF NOT EXISTS \`${PROJECT_ID}.${DATASET}.community_demographics\` (
    region STRING,
    country STRING,
    population INT64,
    vulnerable_population_pct FLOAT64,
    hospital_count INT64,
    shelter_capacity INT64,
    avg_response_time_minutes FLOAT64,
    mobile_coverage_pct FLOAT64,
    elevation_meters FLOAT64,
    flood_risk_zone STRING,
    earthquake_zone INT64
);
"

echo "Loading community_demographics data..."
bq query --use_legacy_sql=false --project_id=$PROJECT_ID "
INSERT INTO \`${PROJECT_ID}.${DATASET}.community_demographics\` VALUES
('Metro Manila', 'Philippines', 13920000, 32.5, 485, 250000, 45, 95.0, 16, 'high', 4),
('Quezon City', 'Philippines', 2960000, 30.1, 98, 52000, 38, 96.0, 40, 'medium', 4),
('Mumbai Metropolitan', 'India', 20410000, 28.7, 620, 180000, 55, 88.0, 14, 'high', 3),
('Tokyo Metropolitan', 'Japan', 13960000, 38.2, 1200, 450000, 12, 99.5, 40, 'medium', 5),
('Ishikawa Prefecture', 'Japan', 1120000, 42.1, 89, 35000, 18, 97.0, 20, 'medium', 5),
('Jakarta', 'Indonesia', 10560000, 26.3, 310, 120000, 65, 85.0, 8, 'high', 4),
('Dhaka Division', 'Bangladesh', 21740000, 34.8, 280, 95000, 90, 72.0, 4, 'high', 2),
('Townsville', 'Australia', 195000, 25.4, 12, 15000, 22, 98.0, 15, 'high', 1),
('Sydney Greater', 'Australia', 5310000, 27.9, 380, 200000, 18, 99.0, 58, 'low', 2),
('Kathmandu Valley', 'Nepal', 3000000, 31.5, 65, 28000, 75, 80.0, 1400, 'low', 5),
('Hualien County', 'Taiwan', 320000, 35.2, 18, 12000, 15, 94.0, 30, 'medium', 5),
('Hanoi', 'Vietnam', 8050000, 29.4, 195, 85000, 48, 90.0, 12, 'high', 2),
('Colombo', 'Sri Lanka', 753000, 30.8, 45, 22000, 35, 92.0, 7, 'high', 2),
('Queensland Coast', 'Australia', 520000, 26.0, 28, 18000, 25, 96.0, 10, 'high', 1),
('Shanghai', 'China', 24870000, 33.1, 890, 380000, 20, 98.0, 4, 'high', 3),
('Taipei', 'Taiwan', 2600000, 36.5, 210, 95000, 14, 99.0, 9, 'medium', 5),
('Christchurch', 'New Zealand', 380000, 28.3, 22, 16000, 20, 97.0, 20, 'high', 5),
('Suva', 'Fiji', 93000, 33.0, 8, 5000, 45, 75.0, 6, 'high', 2),
('Bangkok', 'Thailand', 10540000, 27.6, 420, 150000, 40, 94.0, 2, 'high', 1),
('Yangon', 'Myanmar', 5160000, 30.2, 120, 45000, 85, 68.0, 20, 'high', 3);
"

# -------------------------------------------------------------------
# Table 3: historical_disasters
# -------------------------------------------------------------------
echo "Creating historical_disasters table..."
bq query --use_legacy_sql=false --project_id=$PROJECT_ID "
CREATE TABLE IF NOT EXISTS \`${PROJECT_ID}.${DATASET}.historical_disasters\` (
    event_id STRING,
    event_type STRING,
    country STRING,
    region STRING,
    year INT64,
    month INT64,
    magnitude_or_category STRING,
    affected_population INT64,
    fatalities INT64,
    economic_damage_usd_millions FLOAT64,
    response_time_hours FLOAT64,
    lessons_learned STRING
);
"

echo "Loading historical_disasters data..."
bq query --use_legacy_sql=false --project_id=$PROJECT_ID "
INSERT INTO \`${PROJECT_ID}.${DATASET}.historical_disasters\` VALUES
('HIST-PH-2013-001', 'typhoon', 'Philippines', 'Visayas', 2013, 11, 'Category 5', 16000000, 6300, 2860, 8.5, 'Pre-positioned supplies critical. Evacuation orders must be enforced not advisory.'),
('HIST-JP-2011-001', 'earthquake', 'Japan', 'Tohoku', 2011, 3, 'M9.1', 368000, 19747, 235000, 1.5, 'Tsunami walls insufficient. Real-time warning systems essential.'),
('HIST-IN-2005-001', 'flood', 'India', 'Maharashtra', 2005, 7, 'Extreme', 20000000, 1200, 3500, 12.0, 'Urban drainage infrastructure critical. Early warning for coastal cities needed.'),
('HIST-ID-2004-001', 'tsunami', 'Indonesia', 'Aceh', 2004, 12, 'M9.1 triggered', 500000, 166000, 14000, 4.0, 'Indian Ocean warning system created after. Community education on natural signs vital.'),
('HIST-NP-2015-001', 'earthquake', 'Nepal', 'Kathmandu', 2015, 4, 'M7.8', 8000000, 8969, 10000, 6.0, 'Building codes enforcement vital. Helicopter access for mountain communities critical.'),
('HIST-AU-2020-001', 'wildfire', 'Australia', 'New South Wales', 2020, 1, 'Catastrophic', 3000000, 34, 100000, 3.0, 'Climate change accelerating fire seasons. Community evacuation plans essential.'),
('HIST-PH-2020-001', 'typhoon', 'Philippines', 'Luzon', 2020, 11, 'Category 5', 3900000, 73, 1100, 5.0, 'Compound disaster with COVID complicated evacuations. Digital communication critical.'),
('HIST-JP-2024-001', 'earthquake', 'Japan', 'Ishikawa', 2024, 1, 'M7.5', 350000, 245, 8500, 2.0, 'Noto Peninsula road damage delayed rescue. Pre-staged supplies in remote areas needed.'),
('HIST-BD-2024-001', 'flood', 'Bangladesh', 'Sylhet', 2024, 6, 'Extreme', 4500000, 42, 1200, 14.0, 'Mobile-first warning systems reach more people than sirens.'),
('HIST-TW-2024-001', 'earthquake', 'Taiwan', 'Hualien', 2024, 4, 'M7.4', 280000, 18, 3200, 1.5, 'Strong building codes saved lives. Tunnel and cliff collapse main dangers.'),
('HIST-ID-2018-001', 'earthquake', 'Indonesia', 'Sulawesi', 2018, 9, 'M7.5', 350000, 4340, 2800, 4.0, 'Liquefaction destroyed entire neighborhoods. Soil assessment critical for rebuilding.'),
('HIST-PK-2022-001', 'flood', 'Pakistan', 'Sindh', 2022, 8, 'Extreme', 33000000, 1739, 30000, 20.0, 'One-third of country submerged. Climate adaptation infrastructure desperately needed.'),
('HIST-VN-2020-001', 'flood', 'Vietnam', 'Central', 2020, 10, 'Severe', 1500000, 249, 1500, 8.0, 'Landslides compounded flooding. Hillside communities most vulnerable.'),
('HIST-MM-2023-001', 'cyclone', 'Myanmar', 'Rakhine', 2023, 5, 'Category 5', 1600000, 145, 2400, 18.0, 'Conflict zones make disaster response extremely difficult. Neutral corridors needed.'),
('HIST-CN-2021-001', 'flood', 'China', 'Henan', 2021, 7, 'Extreme', 14000000, 302, 17500, 6.0, 'Subway flooding killed dozens. Underground infrastructure vulnerability overlooked.');
"

echo ""
echo "=== BigQuery Setup Complete ==="
echo "Dataset: ${PROJECT_ID}:${DATASET}"
echo "Tables created: disaster_alerts, community_demographics, historical_disasters"
echo ""
echo "Verify with: bq ls ${PROJECT_ID}:${DATASET}"
