# PowerFitGym Database System

## Overview

The **PowerFitGym Database System** is a relational database designed for managing the operations of a fitness center. The system supports the management of gym members, trainers, memberships, class schedules, attendance, and payments.

This project demonstrates practical database design and implementation using **Microsoft SQL Server** and **T-SQL**. It was developed as part of a database development project to apply concepts such as relational modeling, normalization, and database programmability.

---

## Objectives of the Project

The main objectives of this database system are to:

* Manage gym member information
* Track memberships and membership types
* Manage trainers and training sessions
* Schedule and track gym classes
* Record attendance for classes
* Store and track member payments
* Provide structured data for reporting and analysis

---

## Technologies Used

* SQL Server Database Engine
* T-SQL (Transact-SQL)
* Microsoft SQL Server Management Studio (SSMS)

---

## Database Features

The database includes several important components commonly used in real-world systems:

### Tables

The system includes relational tables designed to store data about:

* Members
* Trainers
* Memberships
* Classes
* Attendance
* Payments

Each table includes appropriate **primary keys**, **foreign keys**, and **constraints** to ensure data integrity.

---

### Relationships

The database is designed using relational modeling principles. Tables are connected using **foreign key relationships** to maintain referential integrity between related data.

---

### Views

Views are created to simplify data retrieval and support reporting requirements such as:

* Attendance summaries
* Payment history reports
* Trainer schedules
* Internal administrative reports

---

### Stored Procedures

Stored procedures are implemented to automate common database operations and improve efficiency when performing tasks such as retrieving structured data or executing predefined processes.

---

### Triggers

Triggers are used to enforce specific business rules and automate certain actions when data changes occur within the database.

---

## Database Design Documentation

The full database design documentation includes:

* Entity Relationship Diagram (ERD)
* Database structure explanation
* Table descriptions
* Relationship design

See the documentation file:

```
Documentation/PowerFitGym_Database_Design.pdf
```

---

## How to Run the Database

1. Open **SQL Server Management Studio (SSMS)**.
2. Open the SQL script located in:

```
Database/PowerFitGym_Database_Script.sql
```

3. Execute the script.

The script will create the database and all required objects including tables, relationships, views, stored procedures, and triggers.

---

## Learning Outcomes

This project demonstrates understanding of:

* Relational database design
* Normalization
* SQL scripting
* Database programmability
* Data integrity enforcement
* Real-world database system implementation

---

## Author

**Sihle Mntungwa**
Bachelor of Computing – Business Intelligence (Data Science)
Third Year Student

---

## Project Purpose

This project was developed for academic purposes to demonstrate practical database development skills and understanding of relational database systems.
