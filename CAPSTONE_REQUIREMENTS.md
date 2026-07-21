Capstone Requirements Summary
Hybrid Power-Driven Aquaponics with IoT Environmental Control System

This document summarizes the capstone requirements in a developer-readable format so Codex can understand what functions the web app, mobile app, and hardware/ESP32 system should support.

1. Project Purpose

The system is a Hybrid Power-Driven Aquaponics with IoT Environmental Control System.

Its purpose is to help users maintain a stable aquaponics environment by combining:

IoT sensor monitoring
water quality management
aquaculture information management
plant information management
automatic feeding
hybrid/solar backup power monitoring
alerts and reports
user account management

The system should reduce manual monitoring, help users respond to abnormal water conditions, and support healthier fish/crustacean and plant growth.

2. Main Capstone Functions

The capstone requires these main functions:

Aquaponics Environmental Management
Water Quality Information Management
Hybrid Energy Management
Aquaculture Information Management
Aquaponics Plant Information Management

Special features:

Aquaculture Automatic Feeding
Solar Backup Energy
3. Project Scope Split

The project has multiple parts. Do not force every function into the web app.

Web App Scope

The web app should focus on admin-side functions:

Admin authentication
Role-based access
Grower/farmer account management
Admin monitoring overview
Master records/configuration
Reports/history viewing
Alert/event viewing
Contact/Inquiry submission management
Aquaculture and plant records
Compatibility and feeding assistant
Stored data review
Mobile App Scope

The mobile app is primarily for farmers/growers/aquaponics practitioners.

Mobile app functions should include:

Real-time monitoring display
Farmer alerts and notifications
Farmer-friendly feeding guidance
Input of aquaculture status
Input of plant status
Harvest record entry
Monitoring status view
Simple recommendations
Hardware / ESP32 Scope

Hardware and firmware should handle:

Reading pH sensor
Reading water temperature sensor
Reading dissolved oxygen sensor
Reading turbidity sensor
Reading humidity sensor
Sending sensor data to Firebase/database
Automatic feeding trigger
Environmental control actuators
Hybrid/solar power switching
Battery/power status reading

The web app should not directly perform hardware actions unless the backend/ESP32 supports it.

4. Required Functional Requirements
4.1 Sensor Input Requirements

The system should collect:

pH readings
Water temperature readings
Dissolved oxygen readings
Turbidity readings
Humidity readings

These readings are expected to come from IoT sensors installed in the aquaponics setup.

4.2 User Input Requirements

The system should allow users to input:

Aquaculture status
Plant status
Harvest information
Fish/crustacean type
Feeding schedule
Plant monitoring records
Growth information
4.3 Processing Requirements

The system should:

Gather environmental data from IoT sensors
Analyze sensor readings
Compare readings with predefined threshold values
Process data using the microcontroller/backend
Manage aquaculture information in the database
Manage plant monitoring information in the database
Activate automated functions such as fish feeding when required
4.4 Output Requirements

The system should display:

pH level
Water temperature
Dissolved oxygen
Turbidity
Humidity
Real-time monitoring data
System alerts and notifications
Monitoring reports
System activity
Monitoring status
4.5 Stored Data Requirements

The system should store:

Historical water quality data
Aquaculture information
Fish type
Feeding schedule
Plant monitoring records
System activity logs
User accounts
Monitoring data
Harvest records
Alert logs
5. Required Modules and Subfunctions
5.1 Authentication and Access Control

Required behavior:

Only authorized users can access protected parts of the system
Admin users can access the web admin dashboard
Grower/farmer users should not access admin-only web pages
User accounts should be stored in the database
User active/inactive status should be respected

Suggested data:

admin/{uid}
user/{uid}
users/{uid}, if used later
5.2 Water Quality Information Management

Required behavior:

Display water quality parameters
Store historical water quality readings
Validate readings
Compare readings with threshold values
Generate water quality reports
Generate system alerts when abnormal readings are detected

Parameters:

pH
Water temperature
Dissolved oxygen
Turbidity
Humidity

Possible web app functions:

Admin can view historical readings
Admin can view monitoring summaries
Admin can view abnormal readings
Admin can view water quality reports

Possible mobile app functions:

Farmer can view real-time readings
Farmer receives alerts
Farmer can check current water condition
5.3 Aquaponics Environmental Management

Required behavior:

Monitor overall aquaponics environment
Determine whether current water/environment conditions are safe
Compare sensor values against safe ranges
Detect abnormal conditions
Trigger alerts or status warnings
Support stable fish/crustacean and plant growth

Possible implementation:

Threshold-based status engine
Environmental status labels:
Normal
Warning
Critical
Alert generation when readings pass thresholds
5.4 Alerts and Notifications

Required behavior:

Detect abnormal water parameter readings
Send alerts to users
Display alerts/notifications
Log alert events
Keep alert history

Possible web app functions:

Admin alert list
Alert details
Alert status: new, acknowledged, resolved
Filter alerts by severity/status/date
View alert history

Possible mobile app functions:

Farmer receives alert
Farmer sees clear recommended action
5.5 Monitoring Reports

Required behavior:

Provide reports of aquaponics environmental conditions
Show historical monitoring data
Show water quality history
Show system activity/status

Possible reports:

Daily water quality summary
Weekly water quality summary
Environmental condition report
Aquaculture growth report
Plant growth report
Harvest report
Feeding report
Alert report
Power/battery report
5.6 System Activity Logs

Required behavior:

Store system activity logs
Store automated action logs
Show monitoring status
Show system activity

Examples:

Sensor reading received
Alert generated
Feeding action triggered
Power source changed
Battery warning detected
User submitted harvest record
Admin updated grower status
5.7 Aquaculture Information Management

Required behavior:

Manage fish/crustacean information
Store fish/crustacean type
Store growth status
Store feeding conditions
Store feeding schedule
Store aquaculture harvest records
Generate aquaculture harvest/growth reports

Important species scope:

The document mentions fish and crustaceans
Local teammate discussion includes hito/catfish and ulang/prawn
The system can support tilapia, catfish/hito, and prawn/ulang

Possible records:

Aquaculture type
Quantity
Growth stage
Average weight
Health/status notes
Feeding schedule
Harvest date
Harvest quantity
Harvest remarks
5.8 Aquaculture Automatic Feeding

Required behavior:

Support automatic fish feeding when required
Store feeding schedule
Use fish type and feeding data
Allow feeding-related configuration

Important boundary:

The web app/mobile app may configure feeding schedules
The ESP32/hardware performs the actual feeding action

Current useful software function:

Stocking & Feeding Assistant
Feed/day calculation
Feed/session calculation
Growth stage guide
Feeding schedule configuration
5.9 Aquaponics Plant Information Management

Required behavior:

Manage plant information
Store plant type
Store plant growth/status records
Store plant harvest information
Generate plant harvest/growth reports
Notify users when manual plant monitoring is needed

Possible records:

Plant type
Growth stage
Status
Notes
Monitoring date
Harvest date
Harvest quantity
Harvest remarks
5.10 Harvest Record Management

Required behavior:

Allow users to record aquaculture harvest information
Allow users to record plant harvest information
Store harvest records
Generate harvest reports

Possible fields:

harvestType: aquaculture or plant
itemType: fish/crustacean/plant name
quantity
unit
harvestDate
notes
createdBy
createdAt
5.11 Hybrid Energy Management

Required behavior:

Monitor energy output
Monitor battery status
Detect abnormal voltage levels
Send power alerts
Log power alert events
Support solar backup status

Important boundary:

Hardware/ESP32 handles physical power switching
Web/mobile app displays power source, battery status, and alerts

Possible app fields:

currentPowerSource: main or solar
batteryLevel
voltage
backupAvailable
powerStatus
lastPowerAlert
updatedAt
5.12 Solar Backup Energy

Required behavior:

Provide backup power for specific components
Operate for a limited time during outages
Show backup/battery status
Alert when battery/power is abnormal

Possible app function:

Display solar backup status
Display battery percentage
Display power alert history
5.13 Public Page Functions

The public side should include:

Landing page
About Us
Contact Us
Admin Login
Inquiry function for aquaponics practitioners/users
Mobile app download or information area, if applicable

Contact and Inquiry forms should store real submissions in Firebase.

Suggested collections:

contact_submissions
inquiry_submissions
6. Current Development Priority

The project is currently functionality-first.

Do not prioritize major UI/UX redesign right now.

Current priority order:

Authentication and role-based access
Grower/farmer management
Contact and Inquiry submission storage
Alerts and notification logging
Monitoring/report history
Aquaculture records
Plant records
Harvest record management
Feeding schedule/configuration
Hybrid energy/battery status display
Final UI/UX polish after functions are complete
7. Important Rules for Codex
Read PROJECT_STATE.md first before making changes.
Treat PROJECT_STATE.md as the source of truth.
Treat this CAPSTONE_REQUIREMENTS.md file as the capstone requirement reference.
This current project folder is the WEB APP only.
Do not create mobile app screens inside the web app.
Do not modify the separate mobile app folder.
Do not modify hardware/ESP32 firmware.
Do not redesign UI unless required for functionality.
Do not re-add previously removed dashboard sections.
Do not recreate the removed admin-wide Systems page unless explicitly requested.
Do not delete real Firebase data.
Prefer small, safe, functional changes.
After every functional task, update PROJECT_STATE.md.