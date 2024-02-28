-- Keep a log of any SQL queries you execute as you solve the mystery.

-- Get tables
.tables

-- Get table info
.schema

-- Get information from crime scene reports
SELECT description FROM crime_scene_reports
WHERE month = 7 AND day = 28 AND street = 'Humphrey Street';

-- Theft took place at 10:15 am at the Humphrey Street bakery.
-- Interviews were conducted with 3 witnesses. Each interview mentions the bakery.
-- Littering also took place at 16:36 but no witnesses.
SELECT transcript, name FROM interviews
WHERE month = 7 AND day = 28;

-- From the above query we know now:
-- The thief got into a car in the bakery parking lot within 10 mins of the theft. Look for cars that left in that
-- time frame (security footage). - Ruth.
-- Emma owns the bakery. ATM on Leggett Street before arriving at the bakery, the thief withdrew money. - Eugene.
-- When the thief left the bakery they called someone who talked for less than a minute. Thief said they would take the earliest flight
-- from fiftyville tomorrow. Then they asked the person on the phone to purchase the flight ticket. - Raymond.

-- Get information on tables relating to the ATM transaction
.schema atm_transactions
.schema bank_accounts
.schema people

-- Determine what kind of transactions you can have from an ATM (syntax)
SELECT DISTINCT transaction_type FROM atm_transactions;

-- Determine who withdrew from Legget Street on the day of the robbery. Cannot get the time.
SELECT name, amount, phone_number, passport_number, license_plate FROM people
JOIN bank_accounts ON people.id = bank_accounts.person_id
JOIN atm_transactions ON bank_accounts.account_number = atm_transactions.account_number
WHERE month = 7 AND day = 28 AND atm_location = 'Leggett Street' AND transaction_type = 'withdraw';

-- From the above query we know 8 people withdrew money on the day of the robbery. Get data from bakery security logs from that day within the timeframe.
-- Crosslink to the licenseplate and name associated with it. JOIN bakery security logs to people. Then to filter it, need to select where
-- license plate is in the transactions also. To get the same person who withdrew money and was in the parking lot.
SELECT name FROM people
JOIN bakery_security_logs ON bakery_security_logs.license_plate = people.license_plate
WHERE people.license_plate IN -- Since 2 tables were joined with the same column name, need to specify to avoid ambiguity
    (SELECT license_plate FROM people -- This is taken from the query above, nested within this new query.
    JOIN bank_accounts ON people.id = bank_accounts.person_id
    JOIN atm_transactions ON bank_accounts.account_number = atm_transactions.account_number
    WHERE month = 7 AND day = 28 AND atm_location = 'Leggett Street' AND transaction_type = 'withdraw')
AND month = 7 AND day = 28 AND hour = 10 AND minute >= 15 AND minute <= 25; -- Within 10 minutes of the robbery

-- Now we have 4 people who withdrew cash on that day and were also in the parking lot from within 10 minutes of the robbery.
-- Now to look at the phone call and flight.

-- Determine phone calls made that were less than 1 minute on that day
SELECT caller, receiver FROM phone_calls
WHERE month = 7 AND day = 28 AND duration <= 60;

-- Link this to people so we have the name
SELECT name FROM phone_calls
JOIN people ON phone_calls.caller = people.phone_number
WHERE month = 7 AND day = 28 AND duration <= 60;

-- Link this to match people present in the query that determined those that withdrew from the ATM and were in the parking lot
SELECT name FROM phone_calls
JOIN people ON phone_calls.caller = people.phone_number
WHERE name IN
    (SELECT name FROM people -- Query for bakery parking lot, nested within phone call query
    JOIN bakery_security_logs ON bakery_security_logs.license_plate = people.license_plate
    WHERE people.license_plate IN -- Since 2 tables were joined with the same column name, need to specify to avoid ambiguity
        (SELECT license_plate FROM people -- Query for ATM withdrawal, nested within bakery parking lot query
        JOIN bank_accounts ON people.id = bank_accounts.person_id
        JOIN atm_transactions ON bank_accounts.account_number = atm_transactions.account_number
        WHERE month = 7 AND day = 28 AND atm_location = 'Leggett Street' AND transaction_type = 'withdraw')
    AND month = 7 AND day = 28 AND hour = 10 AND minute >= 15 AND minute <= 25)
AND month = 7 AND day = 28 AND duration <= 60;

-- This gives 2 suspects: Bruce & Diana. Now need to find who took the earliest flight from fiftyville.
-- Looking at flight records to see what flights there were that day
SELECT hour, minute FROM flights
JOIN airports ON flights.origin_airport_id = airports.id
WHERE month = 7 AND day = 28 AND city = 'Fiftyville'
ORDER BY hour ASC, minute ASC;

-- The above query says the earliest flight from fiftyville was 8:20 the day after (29th).
-- Now to get the passengers from that flight.
SELECT name FROM people
JOIN passengers ON people.passport_number = passengers.passport_number
WHERE flight_id IN
    (SELECT flights.id FROM flights
    JOIN airports ON flights.origin_airport_id = airports.id
    WHERE month = 7 AND day = 29 AND city = 'Fiftyville'
    AND hour =
        (SELECT MIN(hour) FROM flights
        JOIN airports ON flights.origin_airport_id = airports.id
        WHERE month = 7 AND day = 29 AND city = 'Fiftyville')
    AND minute =
        (SELECT MIN(minute) FROM flights
        JOIN airports ON flights.origin_airport_id = airports.id
        WHERE month = 7 AND day = 29 AND city = 'Fiftyville'
        AND hour =
            (SELECT MIN(hour) FROM flights
            JOIN airports ON flights.origin_airport_id = airports.id
            WHERE month = 7 AND day = 29 AND city = 'Fiftyville')));

-- Verify hour and minute with the names
SELECT name, hour, minute FROM people
JOIN passengers ON people.passport_number = passengers.passport_number
JOIN flights ON flights.id = passengers.flight_id
WHERE flight_id IN
    (SELECT flights.id FROM flights
    JOIN airports ON flights.origin_airport_id = airports.id
    WHERE month = 7 AND day = 29 AND city = 'Fiftyville'
    AND hour =
        (SELECT MIN(hour) FROM flights
        JOIN airports ON flights.origin_airport_id = airports.id
        WHERE month = 7 AND day = 29 AND city = 'Fiftyville')
    AND minute =
        (SELECT MIN(minute) FROM flights
        JOIN airports ON flights.origin_airport_id = airports.id
        WHERE month = 7 AND day = 29 AND city = 'Fiftyville'
        AND hour =
            (SELECT MIN(hour) FROM flights
            JOIN airports ON flights.origin_airport_id = airports.id
            WHERE month = 7 AND day = 29 AND city = 'Fiftyville')));


-- Link this passenger list to the query that includes the bakery, ATM withdrawl and phonecall.
SELECT name FROM people
    JOIN passengers ON people.passport_number = passengers.passport_number
    WHERE flight_id IN
        (SELECT flights.id FROM flights
        JOIN airports ON flights.origin_airport_id = airports.id
        WHERE month = 7 AND day = 29 AND city = 'Fiftyville'
        AND hour =
            (SELECT MIN(hour) FROM flights
            JOIN airports ON flights.origin_airport_id = airports.id
            WHERE month = 7 AND day = 29 AND city = 'Fiftyville')
        AND minute =
            (SELECT MIN(minute) FROM flights
            JOIN airports ON flights.origin_airport_id = airports.id
            WHERE month = 7 AND day = 29 AND city = 'Fiftyville'
            AND hour =
                (SELECT MIN(hour) FROM flights
                JOIN airports ON flights.origin_airport_id = airports.id
                WHERE month = 7 AND day = 29 AND city = 'Fiftyville'))
        AND name IN
            (SELECT name FROM phone_calls
            JOIN people ON phone_calls.caller = people.phone_number
            WHERE name IN
                (SELECT name FROM people -- Query for bakery parking lot, nested within phone call query
                JOIN bakery_security_logs ON bakery_security_logs.license_plate = people.license_plate
                WHERE people.license_plate IN -- Since 2 tables were joined with the same column name, need to specify to avoid ambiguity
                    (SELECT license_plate FROM people -- Query for ATM withdrawal, nested within bakery parking lot query
                    JOIN bank_accounts ON people.id = bank_accounts.person_id
                    JOIN atm_transactions ON bank_accounts.account_number = atm_transactions.account_number
                    WHERE month = 7 AND day = 28 AND atm_location = 'Leggett Street' AND transaction_type = 'withdraw')
                AND month = 7 AND day = 28 AND hour = 10 AND minute >= 15 AND minute <= 25)
            AND month = 7 AND day = 28 AND duration <= 60));

-- The thief is Bruce. Now to find out who Bruce called on that day.
-- Re-arrange for the phone calls query to be first, so that we can take the phone number of the receiver.
SELECT name FROM phone_calls
JOIN people ON phone_calls.receiver = people.phone_number -- Join the receivers to the names
WHERE phone_calls.caller = -- Find the receiver who's caller matches Bruce's number
    (SELECT DISTINCT caller FROM phone_calls -- Use the above query but re-arrange with phone calls as the primary query, instead of the name give the caller number
    JOIN people ON phone_calls.caller = people.phone_number
    WHERE name IN
        (SELECT name FROM people -- Query for bakery parking lot, nested within phone call query
        JOIN bakery_security_logs ON bakery_security_logs.license_plate = people.license_plate
        WHERE people.license_plate IN -- Since 2 tables were joined with the same column name, need to specify to avoid ambiguity
            (SELECT license_plate FROM people -- Query for ATM withdrawal, nested within bakery parking lot query
            JOIN bank_accounts ON people.id = bank_accounts.person_id
            JOIN atm_transactions ON bank_accounts.account_number = atm_transactions.account_number
            WHERE month = 7 AND day = 28 AND atm_location = 'Leggett Street' AND transaction_type = 'withdraw' AND name IN
                (SELECT name FROM people -- Query for flight out of Fiftyville
                JOIN passengers ON people.passport_number = passengers.passport_number
                WHERE flight_id IN
                    (SELECT flights.id FROM flights
                    JOIN airports ON flights.origin_airport_id = airports.id
                    WHERE month = 7 AND day = 29 AND city = 'Fiftyville'
                    AND hour =
                        (SELECT MIN(hour) FROM flights
                        JOIN airports ON flights.origin_airport_id = airports.id
                        WHERE month = 7 AND day = 29 AND city = 'Fiftyville')
                    AND minute =
                        (SELECT MIN(minute) FROM flights
                        JOIN airports ON flights.origin_airport_id = airports.id
                        WHERE month = 7 AND day = 29 AND city = 'Fiftyville'
                        AND hour =
                            (SELECT MIN(hour) FROM flights
                            JOIN airports ON flights.origin_airport_id = airports.id
                            WHERE month = 7 AND day = 29 AND city = 'Fiftyville'))))
                AND month = 7 AND day = 28 AND hour = 10 AND minute >= 15 AND minute <= 25)
    AND month = 7 AND day = 28 AND duration <= 60))
    AND month = 7 AND day = 28 AND duration <= 60;

-- Find the destination airport
-- Use query that gave Bruce's name
SELECT city FROM airports
JOIN flights ON airports.id = destination_airport_id
JOIN passengers ON flights.id = passengers.flight_id
WHERE passport_number =
    (SELECT people.passport_number FROM people
        JOIN passengers ON people.passport_number = passengers.passport_number
        WHERE flight_id IN
            (SELECT flights.id FROM flights
            JOIN airports ON flights.origin_airport_id = airports.id
            WHERE month = 7 AND day = 29 AND city = 'Fiftyville'
            AND hour =
                (SELECT MIN(hour) FROM flights
                JOIN airports ON flights.origin_airport_id = airports.id
                WHERE month = 7 AND day = 29 AND city = 'Fiftyville')
            AND minute =
                (SELECT MIN(minute) FROM flights
                JOIN airports ON flights.origin_airport_id = airports.id
                WHERE month = 7 AND day = 29 AND city = 'Fiftyville'
                AND hour =
                    (SELECT MIN(hour) FROM flights
                    JOIN airports ON flights.origin_airport_id = airports.id
                    WHERE month = 7 AND day = 29 AND city = 'Fiftyville'))
            AND name IN
                (SELECT name FROM phone_calls
                JOIN people ON phone_calls.caller = people.phone_number
                WHERE name IN
                    (SELECT name FROM people -- Query for bakery parking lot, nested within phone call query
                    JOIN bakery_security_logs ON bakery_security_logs.license_plate = people.license_plate
                    WHERE people.license_plate IN -- Since 2 tables were joined with the same column name, need to specify to avoid ambiguity
                        (SELECT license_plate FROM people -- Query for ATM withdrawal, nested within bakery parking lot query
                        JOIN bank_accounts ON people.id = bank_accounts.person_id
                        JOIN atm_transactions ON bank_accounts.account_number = atm_transactions.account_number
                        WHERE month = 7 AND day = 28 AND atm_location = 'Leggett Street' AND transaction_type = 'withdraw')
                    AND month = 7 AND day = 28 AND hour = 10 AND minute >= 15 AND minute <= 25)
                AND month = 7 AND day = 28 AND duration <= 60)));
