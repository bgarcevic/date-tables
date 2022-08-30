SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Boris Garcevic
-- Create date: 2022-08-30
-- Description:	Created an extended date table with relevant date columns. Should be run everyday
-- =============================================
DROP PROCEDURE [dbo].[CreateDimDates]
GO 

CREATE PROCEDURE dbo.CreateDimDates
@StartDate DATE = '2015-01-01',
@YearsIntoFuture INT = 1, -- How many years into the future before cut off
@Language NVARCHAR = 'Danish', -- English/Danish supported
@FirstDayOfTheWeek INT = 1 -- 1 = Monday, 7 = Sunday
AS
BEGIN
SET NOCOUNT ON;
IF EXISTS
(
    SELECT *
    FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[dim].[Dates]')
          AND type IN ( N'U' )
)
    DROP TABLE [dim].[Dates];


CREATE TABLE [dim].[Dates]
(
    [SK_Date] [INT],
    [Date] [DATE] NULL,
    [Year] [INT] NULL,
    [StartOfYear] [DATE] NULL,
    [EndOfYear] [DATE] NULL,
    [DayOfYear] [INT] NULL,
    [CurrentYearOffset] [INT] NULL,
    [YearCompleted] [INT] NOT NULL,
    [QuarterNumber] [INT] NULL,
    [Quarter] [NVARCHAR](2) NULL,
    [StartOfQuarter] [DATE] NULL,
    [EndOfQuarter] [DATE] NULL,
    [QuarterAndYear] [NVARCHAR](7) NULL,
    [QuarterYearNumber] [NVARCHAR](5) NULL,
    [CurrentQuarterOffset] [INT] NULL,
    [QuarterCompleted] [INT] NOT NULL,
    [Month] [INT] NULL,
    [StartOfMonth] [DATE] NULL,
    [EndOfMonth] [DATE] NULL,
    [MonthAndYear] [NVARCHAR](8) NULL,
    [MonthYearNumber] [NVARCHAR](7) NULL,
    [CurrentMonthOffset] [INT] NULL,
    [MonthCompleted] [INT] NOT NULL,
    [MonthName] [NVARCHAR](30) NULL,
    [MonthShort] [NVARCHAR](3) NULL,
    [MonthInitial] [NVARCHAR](1) NULL,
    [DayOfMonth] [INT] NULL,
    [Week] [INT] NULL,
    [ISOWeek] [INT] NULL,
    [StartOfWeek] [DATE] NULL,
    [EndOfWeek] [DATE] NULL,
    [WeekAndYear] [NVARCHAR](8) NULL,
    [ISOWeekAndYear] [NVARCHAR](8) NULL,
    [YearWeekNumber] [INT] NULL,
    [ISOYearWeekNumber] [INT] NULL,
    [CurrentWeekOffset] [INT] NULL,
    [WeekCompleted] [INT] NOT NULL,
    [DayOfWeekNumber] [INT] NULL,
    [DayName] [NVARCHAR](30) NULL,
    [DayInitial] [NVARCHAR](1) NULL,
    [WeekInMonth] [INT] NULL,
    [IsAfterToday] [INT] NOT NULL,
    [IsWeekend] [INT] NOT NULL,
    [IsLeapYear] [INT] NOT NULL,
    [Has53Weeks] [INT] NOT NULL,
    [Has53ISOWeeks] [INT] NOT NULL
        CONSTRAINT [PK_DimDates_Date]
        PRIMARY KEY CLUSTERED ([SK_Date] ASC)
        WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON,
              ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF
             ) ON [PRIMARY]
) ON [PRIMARY];

DECLARE @CutoffDate DATE = DATEADD(YEAR, @YearsIntoFuture, DATEFROMPARTS(YEAR(GETDATE()), 12, 31));
SET LANGUAGE @Language;
-- This line changes the date format and languge. See available languages: SELECT * FROM sys.syslanguages;
-- If needed set specific day as first day of week.
SET DATEFIRST 1;
WITH seq (n)
AS (SELECT 0
    UNION ALL
    SELECT n + 1
    FROM seq
    WHERE n < DATEDIFF(DAY, @StartDate, @CutoffDate)),
     Dates (CurrentDate)
AS (SELECT DATEADD(DAY, n, @StartDate)
    FROM seq),
     [CoreDates]
AS (SELECT YEAR([CurrentDate]) * 10000 + MONTH([CurrentDate]) * 100 + DAY([CurrentDate]) AS SK_Date,
           CONVERT(DATE, [CurrentDate]) AS [Date],
           DATEPART(DAY, [CurrentDate]) AS [DayOfMonth],
           DATENAME(WEEKDAY, [CurrentDate]) AS [DayName],
           DATEPART(WEEK, [CurrentDate]) AS [Week],
           DATEPART(ISO_WEEK, [CurrentDate]) AS [ISOWeek],
           DATEPART(WEEKDAY, [CurrentDate]) AS [DayOfWeekNumber],
           DATEPART(MONTH, [CurrentDate]) AS [Month],
           DATENAME(MONTH, [CurrentDate]) AS [MonthName],
           DATEPART(QUARTER, [CurrentDate]) AS [Quarter],
           DATEPART(YEAR, [CurrentDate]) AS [Year],
           DATEFROMPARTS(YEAR([CurrentDate]), MONTH([CurrentDate]), 1) AS [StartOfMonth],
           EOMONTH([CurrentDate]) AS [EndOfMonth],
           DATEFROMPARTS(YEAR([CurrentDate]), 12, 31) AS [EndOfYear],
           DATEPART(DAYOFYEAR, [CurrentDate]) AS [DayOfYear]
    FROM Dates),
     DimDates
AS (SELECT [CoreDates].SK_Date,
           [CoreDates].[Date],
           [CoreDates].[Year],
           DATEFROMPARTS([CoreDates].Year, 1, 1) AS [StartOfYear],
           [CoreDates].EndOfYear,
           [CoreDates].DayOfYear,
           [CoreDates].[Year] - YEAR(GETDATE()) AS [CurrentYearOffset],
           CASE
               WHEN [CoreDates].[Year] < YEAR(GETDATE()) THEN
                   1
               ELSE
                   0
           END AS [YearCompleted],
           [CoreDates].[Quarter] AS [QuarterNumber],
           N'Q' + CAST([CoreDates].[Quarter] AS NVARCHAR(1)) AS [Quarter],
           MIN(Date) OVER (PARTITION BY [Year], [Quarter]) AS [StartOfQuarter],
           EndOfQuarter = MAX([Date]) OVER (PARTITION BY [Year], [Quarter]),
           N'Q' + CAST([CoreDates].[Quarter] AS NVARCHAR(1)) + ' ' + CAST([CoreDates].[Year] AS NVARCHAR(4)) QuarterAndYear,
           CAST([CoreDates].[Year] AS NVARCHAR(4)) + CAST([CoreDates].[Quarter] AS NVARCHAR(1)) AS [QuarterYearNumber],
           DATEDIFF(QUARTER, GETDATE(), [CoreDates].[Date]) AS [CurrentQuarterOffset],
           CASE
               WHEN DATEDIFF(QUARTER, GETDATE(), [CoreDates].[Date]) < 0 THEN
                   1
               ELSE
                   0
           END AS [QuarterCompleted],
           [CoreDates].[Month],
           [CoreDates].[StartOfMonth],
           [CoreDates].[EndOfMonth],
           LEFT(CoreDates.[MonthName], 3) + N' ' + CAST([CoreDates].[Year] AS NVARCHAR(4)) AS [MonthAndYear],
           CAST([CoreDates].[Year] * 10 AS NVARCHAR(5)) + CAST([CoreDates].[Month] AS NVARCHAR(2)) AS [MonthYearNumber],
           DATEDIFF(MONTH, GETDATE(), [CoreDates].[Date]) AS [CurrentMonthOffset],
           CASE
               WHEN DATEDIFF(MONTH, GETDATE(), [CoreDates].[Date]) < 0 THEN
                   1
               ELSE
                   0
           END AS MonthCompleted,
           [CoreDates].[MonthName],
           LEFT([CoreDates].[MonthName], 3) AS [MonthShort],
           LEFT([CoreDates].[MonthName], 1) AS [MonthInitial],
           [CoreDates].[DayOfMonth],
           [CoreDates].[Week],
           [CoreDates].ISOWeek,
           DATEADD(DAY, 1 - DATEPART(WEEKDAY, [CoreDates].[Date]), [CoreDates].[Date]) AS [StartOfWeek],
           DATEADD(DAY, 7 - DATEPART(WEEKDAY, [CoreDates].[Date]), [CoreDates].[Date]) AS [EndOfWeek],
           CASE
               WHEN @@LANGUAGE = 'Dansk' THEN
                   N'U' + CAST([CoreDates].[Week] AS NVARCHAR(2)) + N' ' + CAST([CoreDates].[Year] AS NVARCHAR(4))
               ELSE
                   N'W' + CAST([CoreDates].[Week] AS NVARCHAR(2)) + N' ' + CAST([CoreDates].[Year] AS NVARCHAR(4))
           END AS [WeekAndYear],
           CASE
               WHEN @@LANGUAGE = 'Dansk' THEN
                   N'U' + CAST([CoreDates].[ISOWeek] AS NVARCHAR(2)) + N' '
                   + CAST(YEAR(DATEADD(DAY, 26 - (DATEPART(ISO_WEEK, [CoreDates].Date)), [CoreDates].Date)) AS NVARCHAR(4))
               ELSE
                   N'W' + CAST([CoreDates].[ISOWeek] AS NVARCHAR(2)) + N' '
                   + CAST(YEAR(DATEADD(DAY, 26 - (DATEPART(ISO_WEEK, [CoreDates].Date)), [CoreDates].Date)) AS NVARCHAR(4))
           END AS [ISOWeekAndYear],
           [CoreDates].[Year] * 100 + [CoreDates].[Week] AS [YearWeekNumber],
           YEAR(DATEADD(DAY, 26 - (DATEPART(ISO_WEEK, [CoreDates].Date)), [CoreDates].Date)) * 100
           + DATEPART(ISO_WEEK, [CoreDates].Date) AS [ISOYearWeekNumber],
           DATEDIFF(WEEK, GETDATE(), [CoreDates].[Date]) AS [CurrentWeekOffset],
           CASE
               WHEN DATEDIFF(WEEK, GETDATE(), [CoreDates].[Date]) < 0 THEN
                   1
               ELSE
                   0
           END AS [WeekCompleted],
           [CoreDates].[DayOfWeekNumber],
           [CoreDates].[DayName],
           LEFT([CoreDates].[DayName], 1) AS DayInitial,
           ROW_NUMBER() OVER (PARTITION BY [CoreDates].StartOfMonth,
                                           [CoreDates].[DayOfWeekNumber]
                              ORDER BY [CoreDates].Date
                             ) AS [WeekInMonth],
           CASE
               WHEN [CoreDates].Date <= GETDATE() THEN
                   0
               ELSE
                   1
           END [IsAfterToday],
           CASE
               WHEN [DayOfWeekNumber] IN ( 6, 7 ) THEN
                   1
               ELSE
                   0
           END AS [IsWeekend],
           CASE
               WHEN (Year % 400 = 0)
                    OR
                    (
                        Year % 4 = 0
                        AND Year % 100 <> 0
                    ) THEN
                   1
               ELSE
                   0
           END AS [IsLeapYear],
           CASE
               WHEN DATEPART(WEEK, [CoreDates].EndOfYear) = 53 THEN
                   1
               ELSE
                   0
           END [Has53Weeks],
           CASE
               WHEN DATEPART(ISO_WEEK, [CoreDates].EndOfYear) = 53 THEN
                   1
               ELSE
                   0
           END [Has53ISOWeeks]
    FROM [CoreDates])
INSERT INTO dim.Dates
SELECT DimDates.SK_Date,
       DimDates.Date,
       DimDates.Year,
       DimDates.StartOfYear,
       DimDates.EndOfYear,
       DimDates.DayOfYear,
       DimDates.CurrentYearOffset,
       DimDates.YearCompleted,
       DimDates.QuarterNumber,
       DimDates.Quarter,
       DimDates.StartOfQuarter,
       DimDates.EndOfQuarter,
       DimDates.QuarterAndYear,
       DimDates.QuarterYearNumber,
       DimDates.CurrentQuarterOffset,
       DimDates.QuarterCompleted,
       DimDates.Month,
       DimDates.StartOfMonth,
       DimDates.EndOfMonth,
       DimDates.MonthAndYear,
       DimDates.MonthYearNumber,
       DimDates.CurrentMonthOffset,
       DimDates.MonthCompleted,
       DimDates.MonthName,
       DimDates.MonthShort,
       DimDates.MonthInitial,
       DimDates.DayOfMonth,
       DimDates.Week,
       DimDates.ISOWeek,
       DimDates.StartOfWeek,
       DimDates.EndOfWeek,
       DimDates.WeekAndYear,
       DimDates.ISOWeekAndYear,
       DimDates.YearWeekNumber,
       DimDates.ISOYearWeekNumber,
       DimDates.CurrentWeekOffset,
       DimDates.WeekCompleted,
       DimDates.DayOfWeekNumber,
       DimDates.DayName,
       DimDates.DayInitial,
       DimDates.WeekInMonth,
       DimDates.IsAfterToday,
       DimDates.IsWeekend,
       DimDates.IsLeapYear,
       DimDates.Has53Weeks,
       DimDates.Has53ISOWeeks
FROM DimDates
ORDER BY Date
OPTION (MAXRECURSION 0);
SET LANGUAGE English; -- Default Language

END
GO
