/* ---------- 0. Create / switch to DB ---------- */
IF DB_ID(N'PowerFitGym') IS NULL
BEGIN
    CREATE DATABASE PowerFitGym;
END;
GO
ALTER DATABASE PowerFitGym SET COMPATIBILITY_LEVEL = 160;
GO
USE PowerFitGym;
GO

/* ---------- 1. Tables ---------- */
CREATE TABLE dbo.Membership(
    MembershipID   INT IDENTITY PRIMARY KEY,
    MembershipType VARCHAR(50)  NOT NULL,
    StartDate      DATE         NOT NULL,
    EndDate        DATE         NOT NULL,
    Price          DECIMAL(10,2) CHECK (Price>=0),
    Status         VARCHAR(20)   CHECK (Status IN ('Active','Expired','Cancelled'))
);
GO

CREATE TABLE dbo.Member(
    MemberID     INT IDENTITY PRIMARY KEY,
    FirstName    VARCHAR(50) NOT NULL,
    LastName     VARCHAR(50) NOT NULL,
    DateOfBirth  DATE        NULL,
    Email        VARCHAR(100) UNIQUE,
    PhoneNumber  VARCHAR(20)  UNIQUE,
    Address      VARCHAR(200),
    MembershipID INT NOT NULL
        FOREIGN KEY REFERENCES dbo.Membership(MembershipID)
);
GO

CREATE TABLE dbo.Trainer(
    TrainerID   INT IDENTITY PRIMARY KEY,
    FirstName   VARCHAR(50) NOT NULL,
    LastName    VARCHAR(50) NOT NULL,
    Specialty   VARCHAR(100),
    Email       VARCHAR(100) UNIQUE,
    PhoneNumber VARCHAR(20)  UNIQUE
);
GO

CREATE TABLE dbo.ClassType(
    ClassID     INT IDENTITY PRIMARY KEY,
    ClassName   VARCHAR(100) NOT NULL,
    Description VARCHAR(500)
);
GO

CREATE TABLE dbo.ClassSchedule(
    ScheduleID    INT IDENTITY PRIMARY KEY,
    ClassID       INT NOT NULL
        FOREIGN KEY REFERENCES dbo.ClassType(ClassID),
    TrainerID     INT NOT NULL
        FOREIGN KEY REFERENCES dbo.Trainer(TrainerID),
    ScheduledDate DATE NOT NULL,
    StartTime     TIME NOT NULL,
    EndTime       TIME NOT NULL,
    MaxCapacity   INT  NOT NULL CHECK (MaxCapacity>0)
);
GO

CREATE TABLE dbo.Attendance(
    AttendanceID     INT IDENTITY PRIMARY KEY,
    ScheduleID       INT NOT NULL
        FOREIGN KEY REFERENCES dbo.ClassSchedule(ScheduleID),
    MemberID         INT NOT NULL
        FOREIGN KEY REFERENCES dbo.Member(MemberID),
    AttendanceStatus VARCHAR(20) CHECK (AttendanceStatus IN ('Present','Absent','Pending')),
    PerformanceNotes VARCHAR(500),
    CONSTRAINT uq_Attendance UNIQUE(MemberID,ScheduleID)
);
GO

CREATE TABLE dbo.Payment(
    PaymentID     INT IDENTITY PRIMARY KEY,
    MemberID      INT NOT NULL
        FOREIGN KEY REFERENCES dbo.Member(MemberID),
    PaymentDate   DATE        NOT NULL DEFAULT (CONVERT(date,GETDATE())),
    Amount        DECIMAL(10,2) NOT NULL CHECK (Amount>0),
    PaymentMethod VARCHAR(20)   CHECK (PaymentMethod IN ('EFT','Cash','Card')),
    PaymentStatus VARCHAR(20)   CHECK (PaymentStatus IN ('Pending','Failed','Paid'))
);
GO

CREATE TABLE dbo.PaymentUpdateLog(
    LogID      INT IDENTITY PRIMARY KEY,
    PaymentID  INT,
    OldAmount  DECIMAL(10,2),
    NewAmount  DECIMAL(10,2),
    UpdateDate DATETIME DEFAULT (GETDATE())
);
GO

/* ---------- 2. Triggers ---------- */
CREATE OR ALTER TRIGGER trg_LogPaymentChange
ON dbo.Payment
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.PaymentUpdateLog(PaymentID,OldAmount,NewAmount)
    SELECT d.PaymentID,d.Amount,i.Amount
    FROM inserted i
    JOIN deleted  d ON d.PaymentID=i.PaymentID
    WHERE d.Amount<>i.Amount;
END;
GO

CREATE OR ALTER TRIGGER trg_PreventDoubleBooking
ON dbo.Attendance
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    /* overlap check */
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.ClassSchedule n ON n.ScheduleID=i.ScheduleID
        JOIN dbo.Attendance    a ON a.MemberID=i.MemberID
        JOIN dbo.ClassSchedule e ON e.ScheduleID=a.ScheduleID
        WHERE n.ScheduledDate=e.ScheduledDate
          AND n.StartTime < e.EndTime
          AND e.StartTime < n.EndTime
    )
        THROW 50020,'Overlapping class booking.',1;

    /* capacity check */
    IF EXISTS (
        SELECT 1
        FROM inserted i
        CROSS APPLY (
            SELECT cnt = COUNT(*) FROM dbo.Attendance WHERE ScheduleID=i.ScheduleID
        ) c
        JOIN dbo.ClassSchedule cs ON cs.ScheduleID=i.ScheduleID
        WHERE c.cnt >= cs.MaxCapacity
    )
        THROW 50021,'Class capacity exceeded.',1;

    INSERT dbo.Attendance(ScheduleID,MemberID,AttendanceStatus,PerformanceNotes)
    SELECT ScheduleID,MemberID,AttendanceStatus,PerformanceNotes
    FROM inserted;
END;
GO

/* ---------- 3. Function ---------- */
CREATE OR ALTER FUNCTION dbo.udf_CalculateAge
(
    @DateOfBirth DATE,
    @AsOfDate    DATE = NULL
)
RETURNS TABLE
AS
RETURN
SELECT Age =
       DATEDIFF(YEAR,@DateOfBirth,COALESCE(@AsOfDate,CAST(GETDATE() AS DATE)))
     - CASE WHEN FORMAT(@DateOfBirth,'MMdd') >
                 FORMAT(COALESCE(@AsOfDate,GETDATE()),'MMdd') THEN 1 ELSE 0 END;
GO

/* ---------- 4. Views ---------- */
CREATE OR ALTER VIEW dbo.vw_MemberDetails
AS
SELECT m.MemberID,
       CONCAT(m.FirstName,' ',m.LastName) AS FullName,
       m.Email,m.PhoneNumber,m.Address,
       s.MembershipType,s.Status,s.StartDate,s.EndDate
FROM   dbo.Member m
JOIN   dbo.Membership s ON s.MembershipID=m.MembershipID;
GO

CREATE OR ALTER VIEW dbo.vw_ClassSchedules
AS
SELECT cs.ScheduleID,c.ClassName,cs.ScheduledDate,cs.StartTime,cs.EndTime,
       cs.MaxCapacity,CONCAT(t.FirstName,' ',t.LastName) AS TrainerName
FROM   dbo.ClassSchedule cs
JOIN   dbo.ClassType c ON c.ClassID=cs.ClassID
JOIN   dbo.Trainer   t ON t.TrainerID=cs.TrainerID;
GO

CREATE OR ALTER VIEW dbo.vw_AttendanceSummary
AS
SELECT a.AttendanceID,
       CONCAT(m.FirstName,' ',m.LastName) AS MemberName,
       c.ClassName,
       a.AttendanceStatus,
       a.PerformanceNotes
FROM dbo.Attendance a
JOIN dbo.Member        m  ON m.MemberID=a.MemberID
JOIN dbo.ClassSchedule cs ON cs.ScheduleID=a.ScheduleID
JOIN dbo.ClassType     c  ON c.ClassID=cs.ClassID;
GO

CREATE OR ALTER VIEW dbo.vw_MembershipSummary
AS
SELECT m.MemberID, 
       CONCAT(m.FirstName, ' ', m.LastName) AS MemberName, 
       ms.MembershipType, 
       ms.Status,
       ms.StartDate, 
       ms.EndDate, 
       ms.Price
FROM dbo.Member m
JOIN dbo.Membership ms ON m.MembershipID = ms.MembershipID;
GO

CREATE OR ALTER VIEW dbo.vw_PaymentSummary
AS
SELECT p.PaymentID, 
       CONCAT(m.FirstName, ' ', m.LastName) AS MemberName, 
       p.PaymentDate, 
       p.Amount, 
       p.PaymentMethod, 
       p.PaymentStatus
FROM dbo.Payment p
JOIN dbo.Member m ON m.MemberID = p.MemberID;
GO

/* ---------- 5. Indexes ---------- */
CREATE INDEX ix_Member_Email     ON dbo.Member(Email);
GO
CREATE INDEX ix_Payment_MemberID ON dbo.Payment(MemberID);
GO
CREATE INDEX ix_Att_ScheduleID   ON dbo.Attendance(ScheduleID);
GO

/* ---------- 6. Sample data ---------- */
/* Memberships */
INSERT dbo.Membership (MembershipType,StartDate,EndDate,Price,Status) VALUES
('Monthly','2025-04-01','2025-04-30',  450 ,'Active'),
('Annual' ,'2025-01-01','2025-12-31', 4500 ,'Active'),
('Monthly','2025-03-01','2025-03-31',  450 ,'Expired');
GO

/* Members */
INSERT dbo.Member (FirstName,LastName,DateOfBirth,Email,PhoneNumber,Address,MembershipID) VALUES
('Nomsa','Khumalo','1995-06-15','nomsa.khumalo@gmail.com','0761234567','12 Vilakazi Street, Soweto',1),
('Sibusiso','Mahlangu','1988-09-25','sibusiso.mahlangu@gmail.com','0742345678','88 Long Street, Johannesburg',2),
('Ayanda','Pillay','2000-01-10','ayanda.pillay@gmail.com','0783456789','45 Florida Road, Northcliff',3),
('Thato','Radebe','1992-07-21','thato.radebe@gmail.com','0738881234','16 Main Road, Auckland Park',1),
('Naledi','Mokoena','1985-03-14','naledi.mokoena@gmail.com','0796547890','99 Church St, West Ridge',2),
('Mpho','Ngwenya','1996-09-05','mpho.ngwenya@gmail.com','0761112345','23 Bree St, JHB',1),
('Tshepo','Dube','1989-11-02','tshepo.dube@gmail.com','0724569876','7 Loop St, Kempton Park',2),
('Lerato','Maponya','1993-05-19','lerato.maponya@gmail.com','0712348889','31 High St, Boksburg',3),
('Buhle','Nkuna','1998-12-27','buhle.nkuna@gmail.com','0787894561','10 Govan Mbeki Ave, JHB',2),
('Tumelo','Zwane','1990-01-17','tumelo.zwane@gmail.com','0743216549','4 Voortrekker Rd, Soweto',1),
('Kagiso','Mahlangu','1994-06-04','kagiso.m@gmail.com','0765678901','88 Steve Biko Rd, Tembisa',3),
('Bonolo','Sithole','1987-08-13','bonolo.sithole@gmail.com','0737654321','22 Adderley St, Rosebank',1),
('Siyabonga','Zulu','1986-02-09','siya.zulu@gmail.com','0823332211','5 Mitchell St, Soweto',2),
('Karabo','Ndlovu','1999-10-11','karabo.ndlovu@gmail.com','0814567890','13 Melrose Blvd, Sandton',2),
('Lindiwe','Gumede','1991-04-23','lindi.gumede@gmail.com','0786543212','6 Bridge North, Eastgate',1),
('Boitumelo','Molefe','1995-06-08','boity.molefe@gmail.com','0744441234','75 Central Ave, JHB',3),
('Siphesihle','Nkosi','1982-11-30','s.nkosi@gmail.com','0837775555','14 Old Main Rd, Soweto',2),
('Nthabiseng','Modise','2001-02-16','nmodise@gmail.com','0729988776','99 Ridge Rd, Kempton Park',1);
GO

/* Trainers */
INSERT dbo.Trainer (FirstName,LastName,Specialty,Email,PhoneNumber) VALUES
('Thabo' ,'Mokoena','Yoga'             ,'thabo.mokoena@gym.co.za','0712345678'),
('Lindiwe','Nkosi'  ,'Strength Training','lindiwe.nkosi@gym.co.za','0723456789'),
('Sipho' ,'Dlamini','Cardio'            ,'sipho.dlamini@gym.co.za','0734567890'),
('Zanele','Mthembu','CrossFit'          ,'zanele.mthembu@gym.co.za','0745566778');
GO

/* Class types */
INSERT dbo.ClassType (ClassName,Description) VALUES
('Yoga Beginners' , 'A calming yoga session for beginners.'),
('HIIT'           , 'High Intensity Interval Training class for fat burn.'),
('Zumba'          , 'Fun dance-based cardio workout.'),
('CrossFit Circuit','Intensive circuit-based strength training.');
GO

/* Schedules */
INSERT dbo.ClassSchedule (ClassID,TrainerID,ScheduledDate,StartTime,EndTime,MaxCapacity) VALUES
(1,1,'2025-04-21','08:00','09:00',20),
(2,2,'2025-04-22','18:00','19:00',15),
(3,3,'2025-04-23','10:00','11:00',25),
(4,4,'2025-04-24','07:00','08:00',30);
GO

