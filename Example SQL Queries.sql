--Mattias Tung, Info 330
--lab 4

--1. Write the SQL to determine which customers have booked more than 5 flights between March 3, 2015 and November 12, 2018 arriving in airports in the region of South America
--who have also booked fewer than 10 total flights on planes from Boeing Airplane manufacturer before January 15, 2019.

SELECT C.CustomerID, C.CustomerFname, C.CustomerLname, COUNT(B.BookingID) AS NumBookingsSA
FROM CUSTOMER C
	JOIN BOOKING B ON C.CustomerID = B.CustomerID
	JOIN [ROUTE] R ON B.RouteID = R.RouteID
	JOIN ROUTE_FLIGHT RF ON R.RouteID = RF.RouteID
	JOIN FLIGHT F ON RF.FlightID = F.FlightID
	JOIN AIRPORT A ON F.ArrivalAirportID = A.AirportID
	JOIN CITY CT ON A.CityID = CT.CityID
	JOIN COUNTRY CR ON CT.CountryID = CR.CountryID
	JOIN REGION RE ON CR.RegionID = RE.RegionID
	JOIN
		(SELECT C2.CustomerID, C2.CustomerFname, C2.CustomerLname, COUNT(B2.BookingID) AS NumBookingsBOE
		FROM CUSTOMER C2
			JOIN BOOKING B2 ON C2.CustomerID = B2.CustomerID
			JOIN SEAT_PLANE SP2 ON B2.SeatPlaneClassID = SP2.SeatPlaneClassID
			JOIN PLANE P2 ON SP2.PlaneID = P2.PlaneID 
			JOIN MANUFACTURER M2 ON P2.MfgID = M2.MfgID
		WHERE M2.MfgName = 'Boeing'
			AND B2.BookDateTime < 'January 15, 2019'
		GROUP BY C2.CustomerID, C2.CustomerFname, C2.CustomerLname
		HAVING COUNT(B2.BookingID) < 10) AS Q2 ON C.CustomerID = Q2.CustomerID
WHERE RE.RegionName = 'South America'
	AND B.BookDateTime BETWEEN ('March 3, 2015') AND ('November 12, 2018')
GROUP BY C.CustomerID, C.CustomerFname, C.CustomerLname
HAVING COUNT(B.BookingID) > 5

--2. Write the SQL to determine which employees served in the role of ‘captain’ on greater than 11 flights departing from airport type of ‘military’ from the region of North America 
--who also served in the role of ‘Chief Navigator’ no more than 5 flights arriving to airports in Japan.

SELECT E.EmployeeID, E.EmployeeFname, E.EmployeeLname, COUNT(*) AS NumFlightsMilitary
FROM EMPLOYEE E
	JOIN FLIGHT_EMPLOYEE FE ON E.EmployeeID = FE.EmployeeID
	JOIN [ROLE] R ON FE.RoleID = R.RoleID
	JOIN FLIGHT F ON FE.FlightID = F.FlightID
	JOIN AIRPORT A ON F.DepartAirportID = A.AirportID
	JOIN AIPORT_TYPE ATY ON A.AirportTypeID = ATY.AirportTypeID
	JOIN CITY CT ON A.CityID = CT.CityID
	JOIN COUNTRY CR ON CT.CountryID = CR.CountryID
	JOIN REGION RE ON CR.RegionID = RE.RegionID
	JOIN
		(SELECT E.EmployeeID, E.EmployeeFname, E.EmployeeLname, COUNT(*) AS NumFlightsJapan
		FROM EMPLOYEE E
			JOIN FLIGHT_EMPLOYEE FE ON E.EmployeeID = FE.EmployeeID
			JOIN [ROLE] R ON FE.RoleID = R.RoleID
			JOIN FLIGHT F ON FE.FlightID = F.FlightID
			JOIN AIRPORT A ON F.ArrivalAirportID = A.AirportID
			JOIN CITY CT ON A.CityID = CT.CityID
			JOIN COUNTRY CR ON CT.CountryID = CR.CountryID
		WHERE R.RoleName = 'Chief Navigator'
			AND CR.CountryName = 'Japan'
		GROUP BY E.EmployeeID, E.EmployeeFname, E.EmployeeLname
		HAVING COUNT(*) < 5) AS Q2 ON E.EmployeeID = Q2.EmployeeID
WHERE R.RoleName = 'Captain'
	AND ATY.AirportTypeName = 'Military'
	AND RE.RegionName = 'North America'
GROUP BY E.EmployeeID, E.EmployeeFname, E.EmployeeLname
HAVING COUNT(*) > 11

--3. Write the SQL to create a stored procedure to UPDATE the EMPLOYEE table with new values for City, State and Zip. Use the following parameters:
--@Fname, @Lname, @Birthdate, @NewCity, @NewState, @NewZip
CREATE PROC UpdateEmployee
@Fname varchar(20),
@Lname varchar(20),
@Birthdate date,
@NewCity varchar(20),
@NewState varchar(20),
@NewZip char(5)
AS

BEGIN TRAN A1
UPDATE EMPLOYEE
SET EmployeeCity = @NewCity, EmployeeState = @NewState, EmployeeZip = @NewZip
WHERE EmployeeFname = @Fname AND EmployeeLname = @Lname AND EmployeeDOB = @BirthDate
COMMIT TRAN A1

--4. “No employee younger than 28 years old may serve the role of ‘Principal Engineer’ for routes named ‘Around the world over the Arctic’ scheduled to depart in the month of December”
CREATE FUNCTION NoUnder28PrinEngArtic()
RETURNS INT
AS
BEGIN
	DECLARE @RET INT = 0
	IF EXISTS (
		SELECT *
		FROM EMPLOYEE E
			JOIN FLIGHT_EMPLOYEE FE ON E.EmployeeID = FE.EmployeeID
			JOIN [ROLE] R ON FE.RoleID = R.RoleID
			JOIN FLIGHT F ON FE.FlightID = F.FlightID
			JOIN ROUTE_FLIGHT RF ON F.FlighID = RF.FlightID
			JOIN [ROUTE] RT ON RF.RouteID = RT.RouteID
		WHERE RT.RouteName = 'Around the world over the Arctic'
			AND	MONTH(F.ScheduledDepart) = 'December'
			AND R.RoleName = 'Principal Engineer'
			AND E.EmployeeDOB > (SELECT GetDate() - (365.25 * 28)))
	BEGIN 
		SET @RET = 1
	END
RETURN @RET
END
GO

ALTER TABLE FLIGHT_EMPLOYEE
ADD CONSTRAINT CK_NoUnder28CanDoThat
CHECK (dbo.NoUnder28PrinEngArtic() = 0)
GO

--5. “No more than 12,500 pounds of baggage may be booked on planes of type ‘Puddle Jumper’”
CREATE FUNCTION NoMoreBaggagePuddle()
RETURNS INT
AS
BEGIN
	DECLARE @RET INT = 0
	IF EXISTS (
		SELECT F.FlightID
		FROM PLANE P 
			JOIN PLANE_TYPE PT ON P.PlaneTypeID = PT.PlaneTypeID
			JOIN SEAT_PLANE SP ON P.PlaneID = SP.PlaneID
			JOIN BOOKING B ON SP.SeatPlaneClassID = B.SeatPlaneClassID
			JOIN BAG BG ON B.BookingID = BG.BookingiD
			JOIN [ROUTE] R ON B.RouteID = R.RouteID
			JOIN ROUTE_FLIGHT RF ON R.RouteID = RF.RouteID
			JOIN FLIGHT F ON RF.FlightID = RF.FlightID
		WHERE PT.PlaneTypeName = 'Puddle Jumper'
		GROUP BY F.FlightID
		HAVING SUM(BG.Weight) > 12500
	)
	BEGIN
		SET @RET = 1
	END
RETURN @RET
END
GO

ALTER TABLE BAG
ADD CONSTRAINT CK_NoMoreThanHeavyBaggagePuddle
CHECK (dbo.NoMoreBaggagePuddle() = 0)