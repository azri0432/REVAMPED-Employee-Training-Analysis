-- Exploratory Data Analysis

-- 1. Training program performance summary 
SELECT
Employee_ID,
COUNT(*) AS Total_Participants,
SUM(CASE WHEN Training_Outcome = 'Failed' THEN 1 ELSE 0 END) AS Total_Failed,
SUM(CASE WHEN Training_Outcome = 'Completed' OR Training_Outcome = 'Passed' THEN 1 ELSE 0 END) AS Total_Completed,
ROUND(SUM(CASE WHEN Training_Outcome = 'Failed' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS Failure_Rate,
ROUND(SUM(CASE WHEN Training_Outcome = 'Completed' OR Training_Outcome = 'Passed' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS Success_Rate,
ROUND(SUM(CASE WHEN Training_Outcome = 'Failed' THEN Training_Cost ELSE 0 END)) AS Failed_Training_Losses,
ROUND(SUM(Training_Cost), 2) AS Total_Training_Cost
FROM 
  training_and_development_data 
GROUP BY 
  Training_Program_Name, 
  Employee_ID
ORDER BY 
  Failure_Rate DESC, Total_Training_Cost DESC;
  
-- 2. Training Performance Detail
SELECT 
e.Employee_ID,
e.FirstName,
e.LastName,
e.BusinessUnit,
e.Division,
e.Title,
e.PerformanceScore,
e.CurrentEmployeeRating,
e.EmployeeStatus,
e.TerminationType,
e.ExitDate,
CASE WHEN e.ExitDate IS NULL THEN 'Active' ELSE 'Terminated' END AS Employee_Status_Category,
t.Training_Program_Name,
t.Training_Outcome,
t.Training_Date,
t.Training_Cost,
-- Additional calculated fields for Power BI
CASE WHEN t.Training_Outcome = 'Failed' AND e.ExitDate IS NOT NULL THEN 'Failed_and_Terminated'
	WHEN t.Training_Outcome = 'Failed' AND e.ExitDate IS NULL THEN 'Failed_but_Active'
    ELSE 'Passed_and_Completed' END AS Training_Employment_Status
FROM employee_data e
JOIN training_and_development_data t ON e.Employee_ID = t.Employee_ID
WHERE t.Training_Outcome IS NOT NULL
ORDER BY e.CurrentEmployeeRating ASC, t.Training_Date DESC;

-- 3. Business Unit Training Analysis

SELECT
e.BusinessUnit,
t.Training_Program_Name,
COUNT(DISTINCT e.Employee_ID) AS Unique_Employees_Trained,
COUNT(t.Employee_ID) AS Total_Training_Sessions,
ROUND(AVG(e.CurrentEmployeeRating), 2) AS Avg_Employee_Rating,
ROUND(SUM(t.Training_Cost), 2) AS Total_Training_Investment,
ROUND(SUM(t.Training_Cost) / COUNT(DISTINCT e.Employee_ID), 2) AS Cost_Per_Employee,
SUM(CASE WHEN t.Training_Outcome = 'Failed' THEN 1 ELSE 0 END) AS Failed_Sessions,
SUM(CASE WHEN t.Training_Outcome = 'Completed' OR t.Training_Outcome = 'Passed' THEN 1 ELSE 0 END) AS Passed_Sessions,
ROUND(SUM(CASE WHEN t.Training_Outcome = 'Failed' THEN 1 ELSE 0 END) / COUNT(DISTINCT e.Employee_ID), 2) * 100 AS Unit_Failure_Rate,
-- Rankings
RANK() OVER (ORDER BY AVG(e.CurrentEmployeeRating) DESC) AS Ratings_Rank,
RANK() OVER (ORDER BY SUM(t.Training_Cost) DESC) AS Spendings_Rank,
RANK() OVER (ORDER BY COUNT(DISTINCT e.Employee_ID) DESC) AS Participation_Rank
FROM
	employee_data e
JOIN
	training_and_development_data t ON e.Employee_ID = t.Employee_ID
GROUP BY 
	e.BusinessUnit, t.Training_Program_Name;
    
-- 4. DEI analysis

SELECT
e.RaceDesc, 
e.Employee_ID,
SUM(CASE WHEN Training_Outcome = 'Failed' THEN 1 ELSE 0 END) AS Total_Failed,
SUM(CASE WHEN Training_Outcome = 'Completed' OR Training_Outcome = 'Passed' THEN 1 ELSE 0 END) AS Total_Completed,
ROUND(SUM(CASE WHEN Training_Outcome = 'Failed' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS Failure_Rate,
ROUND(SUM(CASE WHEN Training_Outcome = 'Completed' OR Training_Outcome = 'Passed' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS Success_Rate,
ROUND(SUM(Training_Cost), 2) AS Total_Investment_by_Race,
ROUND(AVG(Training_Cost), 2) AS Avg_Cost_per_Participant,
-- Additional metrics
COUNT(DISTINCT t.Training_Program_Name) AS Unique_Programs_Accessed,
ROUND(AVG(e.CurrentEmployeeRating), 2) AS Avg_Employee_Rating_by_Race
FROM
employee_data e 
JOIN
training_and_development_data t ON e.Employee_ID = t.Employee_ID
GROUP BY
e.RaceDesc, e.Employee_ID;

-- 5. Terminated employee analysis

SELECT
e.Employee_ID,
e.FirstName,
e.LastName,
e.StartDate,
e.ExitDate,
e.BusinessUnit,
e.Title,
e.Supervisor,
e.EmployeeStatus,
e.TerminationType,
e.PerformanceScore,
e.CurrentEmployeeRating,
-- Training Status Columns
COUNT(e.Employee_ID) AS Total_Training_Sessions,
SUM(CASE WHEN Training_Outcome = 'Failed' THEN 1 ELSE 0 END) AS Total_Failed,
SUM(CASE WHEN Training_Outcome = 'Completed' OR Training_Outcome = 'Passed' THEN 1 ELSE 0 END) AS Total_Completed,
ROUND(SUM(t.Training_Cost)) AS Total_Training_Spendings,
-- Time-based calculations
DATEDIFF(COALESCE(STR_TO_DATE(e.ExitDate, '%d-%b-%y'), CURRENT_DATE()), STR_TO_DATE(e.StartDate, '%d-%b-%y')) AS Days_Employed,
CASE
	WHEN e.ExitDate IS NOT NULL AND DATEDIFF(STR_TO_DATE(e.ExitDate, '%d-%b-%y'), STR_TO_DATE(e.StartDate, '%d-%b-%y')) >= 365 THEN 'Standard_Turnover'
    WHEN e.ExitDate IS NOT NULL AND DATEDIFF(STR_TO_DATE(e.ExitDate, '%d-%b-%y'), STR_TO_DATE(e.StartDate, '%d-%b-%y')) < 365 THEN 'High_Turnover'
    ELSE 'Active Employee'
END AS Turnover_Type
FROM employee_data e
LEFT JOIN training_and_development_data t ON e.Employee_ID = t.Employee_ID
WHERE e.EmployeeStatus LIKE '%Terminated%'
GROUP BY e.Employee_ID, e.FirstName, e.LastName, e.StartDate, e.ExitDate, e.BusinessUnit, e.Title, e.Supervisor,
e.EmployeeStatus, e.TerminationType, e.PerformanceScore, e.CurrentEmployeeRating;

-- 6. High spending units with underperforming employees

SELECT
e.Employee_ID,
e.FirstName,
e.LastName,
e.Supervisor,
e.Title,
e.BusinessUnit,
e.PerformanceScore,
e.CurrentEmployeeRating,
t.Training_Program_Name,
t.Training_Outcome,
t.Training_Cost,
t.Training_Date,
-- Business unit aggregations
bu_stats.Total_Unit_Investment,
bu_stats.Unit_Spending_Rankings,
bu_stats.Avg_Unit_Rating,
bu_stats.Unit_Employee_Count,
ROUND(bu_stats.Total_Unit_Investment / bu_stats.Unit_Employee_Count, 2) AS Average_Investment_per_Employee,
-- Performance flags
CASE 
	WHEN e.PerformanceScore = 'Needs Improvement' OR e.PerformanceScore = 'PIP' AND bu_stats.Unit_Spending_Rankings <= 3 THEN 'High-priority intervention'
    WHEN e.PerformanceScore = 'Needs Improvement' AND e.PerformanceScore = 'PIP' THEN 'Standard Intervention'
    ELSE 'Monitoring' 
END AS Intervention_Priority
FROM employee_data e
JOIN training_and_development_data t ON e.Employee_ID = t.Employee_ID
JOIN (
		SELECT e2.BusinessUnit,
        ROUND(SUM(t2.Training_Cost), 2) AS Total_Unit_Investment,
        RANK() OVER (ORDER BY SUM(t2.Training_Cost) DESC) AS Unit_Spending_Rankings,
        ROUND(AVG(e2.CurrentEmployeeRating), 2) AS Avg_Unit_Rating,
        COUNT(DISTINCT e2.Employee_ID) AS Unit_Employee_Count
       FROM employee_data e2
       JOIN training_and_development_data t2 ON e2.Employee_ID = t2.Employee_ID
       GROUP BY e2.BusinessUnit) bu_stats 
       ON e.BusinessUnit = bu_stats.BusinessUnit
WHERE bu_stats.Unit_Spending_Rankings <= 5  -- Top 5 spending units
ORDER BY bu_stats.Unit_Spending_Rankings ASC, 
         CASE WHEN e.PerformanceScore = 'Needs Improvement' THEN 1 ELSE 2 END,
         t.Training_Cost DESC;
         
-- 7. ROI analysis

SELECT 
e.BusinessUnit,
t.Training_Program_name,
COUNT(DISTINCT e.Employee_ID) AS Total_Employees,
COUNT(*) AS Total_Sessions,
ROUND(SUM(t.Training_Cost)) AS Total_Training_Cost,
ROUND(AVG(t.Training_Cost)) AS Average_Training_Cost_per_Session,
SUM(CASE WHEN t.Training_Outcome = 'Completed' OR t.Training_Outcome = 'Passed' THEN 1 ELSE 0 END) AS Total_Passed,
SUM(CASE WHEN t.Training_Outcome = 'Failed' THEN 1 ELSE 0 END) AS Total_Failed,
ROUND(SUM(CASE WHEN t.Training_Outcome = 'Completed' OR t.Training_Outcome = 'Passed' THEN 1 ELSE 0 END) / 
			COUNT(*) * 100, 2) AS Success_Rate,
-- ROI indicators
ROUND(AVG(CASE WHEN t.Training_Outcome = 'Completed' OR t.Training_Outcome = 'Passed' THEN e.CurrentEmployeeRating ELSE NULL END)) AS Avg_Rating_of_Successful_Participants,
ROUND(AVG(CASE WHEN t.Training_Outcome = 'Failed' THEN e.CurrentEmployeeRating ELSE NULL END)) AS Avg_Rating_of_Failed_Participants,
-- Cost efficiency
ROUND(SUM(CASE WHEN t.Training_Outcome = 'Completed' OR t.Training_Outcome = 'Passed' THEN t.Training_Cost ELSE NULL END) / 
NULLIF(SUM(CASE WHEN t.Training_Outcome = 'Completed' OR t.Training_Outcome = 'Passed' THEN 1 ELSE 0 END), 0), 2) AS Cost_Per_Success,
	ROUND(SUM(CASE WHEN t.Training_Outcome = 'Failed' THEN t.Training_Cost ELSE NULL END), 2) AS Wasted_Investment
FROM training_and_development_data t
JOIN employee_data e ON t.Employee_ID = e.Employee_ID
GROUP BY t.Training_Program_Name, e.BusinessUnit
ORDER BY Success_Rate DESC;






