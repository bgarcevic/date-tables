--IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'dim')
--    EXEC ('CREATE SCHEMA [dim]');
--GO

IF EXISTS
(
    SELECT *
    FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[dim].[Dates]')
          AND type IN ( N'U' )
)
    DROP TABLE [dim].[Dates];
GO

SET ANSI_NULLS ON;
GO

SET QUOTED_IDENTIFIER ON;
GO

CREATE TABLE [dim].[Dates]
(
    [SK_Date] [INT],
    [Date] [DATE] NULL,
    [Day] [INT] NULL,
    [DayName] [NVARCHAR](30) NULL,
    [Week] [INT] NULL,
    [ISOWeek] [INT] NULL,
    [WeekInMonth] [TINYINT] NULL,
    [DayOfWeek] [INT] NULL,
    [Month] [INT] NULL,
    [MonthName] [NVARCHAR](30) NULL,
    [Quarter] [INT] NULL,
    [FirstOfQuarter] [DATE] NULL,
    [LastOfQuarter] [DATE] NULL,
    [Year] [INT] NULL,
    [YearWeek] [INT] NULL,
    [ISOYearWeek] [INT] NULL,
    [FirstOfMonth] [DATE] NULL,
    [LastOfMonth] [DATE] NULL,
    [FirstOfYear] [DATE] NULL,
    [LastOfYear] [DATE] NULL,
    [DayOfYear] [INT] NULL,
    [IsAfterToday] [INT] NOT NULL,
    [IsWeekend] [INT] NOT NULL,
    [IsLeapYear] [INT] NULL,
    [Has53Weeks] [INT] NOT NULL,
    [Has53ISOWeeks] [INT] NOT NULL
        CONSTRAINT [PK_DimDates_Date]
        PRIMARY KEY CLUSTERED ([SK_Date] ASC)
        WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON,
              ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF
             ) ON [PRIMARY]
) ON [PRIMARY];
GO


DECLARE @StartDate DATE = '20150101';
DECLARE @YearsIntoFuture INT = 5;
DECLARE @CutoffDate DATE = DATEADD(YEAR, @YearsIntoFuture, DATEFROMPARTS(YEAR(GETDATE()), 12, 31));
SET LANGUAGE English;
-- This line changes the date format and languge. See available languages: SELECT * FROM sys.syslanguages;
-- If needed set specific day as first day of week. 1 = Monday, 7 = Sunday
-- SET DATEFIRST 1;
WITH seq (n)
AS (SELECT 0
    UNION ALL
    SELECT n + 1
    FROM seq
    WHERE n < DATEDIFF(DAY, @StartDate, @CutoffDate)),
     Dates (CurrentDate)
AS (SELECT DATEADD(DAY, n, @StartDate)
    FROM seq),
     CoreDates
AS (SELECT SK_Date = YEAR(CurrentDate) * 10000 + MONTH(CurrentDate) * 100 + DAY(CurrentDate),
           Date = CONVERT(DATE, CurrentDate),
           Day = DATEPART(DAY, CurrentDate),
           DayName = DATENAME(WEEKDAY, CurrentDate),
           Week = DATEPART(WEEK, CurrentDate),
           ISOWeek = DATEPART(ISO_WEEK, CurrentDate),
           DayOfWeek = DATEPART(WEEKDAY, CurrentDate),
           Month = DATEPART(MONTH, CurrentDate),
           MonthName = DATENAME(MONTH, CurrentDate),
           Quarter = DATEPART(QUARTER, CurrentDate),
           Year = DATEPART(YEAR, CurrentDate),
           FirstOfMonth = DATEFROMPARTS(YEAR(CurrentDate), MONTH(CurrentDate), 1),
           LastOfMonth = EOMONTH(CurrentDate),
           LastOfYear = DATEFROMPARTS(YEAR(CurrentDate), 12, 31),
           DayOfYear = DATEPART(DAYOFYEAR, CurrentDate)
    FROM Dates),
     DimDates
AS (SELECT CoreDates.SK_Date,
           CoreDates.Date,
           CoreDates.Day,
           CoreDates.DayName,
           CoreDates.Week,
           CoreDates.ISOWeek,
           WeekInMonth = CONVERT(   TINYINT,
                                    ROW_NUMBER() OVER (PARTITION BY CoreDates.FirstOfMonth,
                                                                    CoreDates.DayOfWeek
                                                       ORDER BY CoreDates.Date
                                                      )
                                ),
           CoreDates.DayOfWeek,
           CoreDates.Month,
           CoreDates.MonthName,
           CoreDates.Quarter,
           FirstOfQuarter = MIN(Date) OVER (PARTITION BY Year, Quarter),
           LastOfQuarter = MAX(Date) OVER (PARTITION BY Year, Quarter),
           CoreDates.Year,
           YearWeek = CoreDates.Year * 100 + CoreDates.Week,
           ISOYearWeek = YEAR(DATEADD(DAY, 26 - (DATEPART(ISO_WEEK, CoreDates.Date)), CoreDates.Date)) * 100
                         + DATEPART(ISO_WEEK, CoreDates.Date),
           CoreDates.FirstOfMonth,
           CoreDates.LastOfMonth,
           FirstOfYear = DATEFROMPARTS(CoreDates.Year, 1, 1),
           CoreDates.LastOfYear,
           CoreDates.DayOfYear,
           IsAfterToday = CASE
                              WHEN CoreDates.Date < GETDATE() THEN
                                  0
                              ELSE
                                  1
                          END,
           IsWeekend = CASE
                           WHEN DayOfWeek IN ( 6, 7 ) THEN
                               1
                           ELSE
                               0
                       END,
           IsLeapYear = CONVERT(   BIT,
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
                                   END
                               ),
           Has53Weeks = CASE
                            WHEN DATEPART(WEEK, LastOfYear) = 53 THEN
                                1
                            ELSE
                                0
                        END,
           Has53ISOWeeks = CASE
                               WHEN DATEPART(ISO_WEEK, LastOfYear) = 53 THEN
                                   1
                               ELSE
                                   0
                           END
    FROM CoreDates)
INSERT INTO dim.Dates
SELECT *
FROM DimDates
ORDER BY Date
OPTION (MAXRECURSION 0);
SET LANGUAGE English; -- Default Language
