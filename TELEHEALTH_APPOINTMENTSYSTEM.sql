-- 1. Database Schema (DDL)

DROP DATABASE IF EXISTS telehealth_b;
CREATE DATABASE telehealth_b;
USE telehealth_b;

-- Users: Stores both patients and doctors with added authentication fields and user status
CREATE TABLE Users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    user_type ENUM('patient', 'doctor') NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL, -- Added for secure password storage
    phone VARCHAR(20),
    date_of_birth DATE,                  -- Made nullable for doctors
    gender ENUM('male', 'female', 'other'), -- Made nullable for doctors
    status ENUM('active', 'inactive', 'suspended') DEFAULT 'active' NOT NULL, -- Added user status
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Specializations: Medical specialties
CREATE TABLE Specializations (
    specialization_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL
);

-- Doctor_Specializations: Many-to-many between doctors and specializations
CREATE TABLE Doctor_Specializations (
    doctor_id INT NOT NULL,
    specialization_id INT NOT NULL,
    PRIMARY KEY (doctor_id, specialization_id),
    FOREIGN KEY (doctor_id) REFERENCES Users(user_id) ON DELETE CASCADE, -- If a doctor is deleted, their specializations are removed
    FOREIGN KEY (specialization_id) REFERENCES Specializations(specialization_id) ON DELETE CASCADE -- If a specialization is deleted, doctor links are removed
);

-- Availability: Doctor's available time slots
-- Removed 'is_booked' as it's redundant and inferred from Appointments
CREATE TABLE Availability (
    availability_id INT AUTO_INCREMENT PRIMARY KEY,
    doctor_id INT NOT NULL,
    start_time DATETIME NOT NULL,
    end_time DATETIME NOT NULL,
    timezone VARCHAR(50) DEFAULT 'Asia/Kolkata', -- Consistent default
    FOREIGN KEY (doctor_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    UNIQUE KEY unique_doctor_slot (doctor_id, start_time, end_time)
);

-- Appointments: Booking records
-- Removed 'appointment_time' as it can be derived from Availability.start_time
CREATE TABLE Appointments (
    appointment_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT NOT NULL,
    doctor_id INT NOT NULL,
    availability_id INT NOT NULL,
    -- No appointment_time here, get it from Availability.start_time
    status ENUM('scheduled', 'completed', 'cancelled', 'rescheduled') DEFAULT 'scheduled',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE (availability_id),
    FOREIGN KEY (patient_id) REFERENCES Users(user_id) ON DELETE RESTRICT, -- Don't delete patient if they have appointments
    FOREIGN KEY (doctor_id) REFERENCES Users(user_id) ON DELETE RESTRICT,   -- Don't delete doctor if they have appointments
    FOREIGN KEY (availability_id) REFERENCES Availability(availability_id) ON DELETE RESTRICT -- Don't delete availability if linked to appointment
);

-- Virtual_Links: Unique video call links per appointment
CREATE TABLE Virtual_Links (
    appointment_id INT PRIMARY KEY, -- Enforces one-to-one relationship
    meeting_url VARCHAR(255) NOT NULL,
    expires_at DATETIME,
    FOREIGN KEY (appointment_id) REFERENCES Appointments(appointment_id) ON DELETE CASCADE -- Delete link if appointment is deleted
);

-- Consultations: Records of the consultation
CREATE TABLE Consultations (
    consultation_id INT AUTO_INCREMENT PRIMARY KEY,
    appointment_id INT UNIQUE NOT NULL, -- Enforces one-to-one relationship
    notes TEXT,
    prescription TEXT,
    outcome TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (appointment_id) REFERENCES Appointments(appointment_id) ON DELETE CASCADE 
);

-- Notifications: Tracks notifications sent
CREATE TABLE Notifications (
    notification_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    appointment_id INT, -- Can be NULL if notification is not appointment-specific
    type ENUM('reminder', 'confirmation', 'cancellation', 'reschedule_confirm') NOT NULL, -- More specific types
    status ENUM('pending', 'sent', 'failed') DEFAULT 'pending',
    sent_at DATETIME,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE, -- If user deleted, notifications are deleted
    FOREIGN KEY (appointment_id) REFERENCES Appointments(appointment_id) ON DELETE SET NULL -- If appointment deleted, set appointment_id to NULL
);

-- Audit_Logs: Logs all key actions
CREATE TABLE Audit_Logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT, -- Can be NULL if action is system-initiated or by an unauthenticated user
    action VARCHAR(100) NOT NULL,
    target_table VARCHAR(50),
    target_id INT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details TEXT,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE SET NULL -- Keep logs even if user is deleted
);

-- Bonus: Recurring_Appointments - Defines a pattern for recurring appointments
CREATE TABLE Recurring_Appointments (
    recurring_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT NOT NULL,
    doctor_id INT NOT NULL,
    specialization_id INT, -- Can be null if patient doesn't specify
    start_date DATE NOT NULL,
    end_date DATE, -- Added to define the end of recurrence
    recurrence_pattern ENUM('daily', 'weekly', 'monthly') NOT NULL,
    occurrences INT, -- Made nullable, if end_date is used, occurrences might be irrelevant
    FOREIGN KEY (patient_id) REFERENCES Users(user_id) ON DELETE RESTRICT,
    FOREIGN KEY (doctor_id) REFERENCES Users(user_id) ON DELETE RESTRICT,
    FOREIGN KEY (specialization_id) REFERENCES Specializations(specialization_id) ON DELETE SET NULL
);
-- Bonus: Feedback (ratings)
-- Removed redundant patient_id and doctor_id
CREATE TABLE Feedback (
    feedback_id INT AUTO_INCREMENT PRIMARY KEY,
    appointment_id INT UNIQUE NOT NULL, -- One feedback per appointment
    rating INT CHECK (rating BETWEEN 1 AND 5) NOT NULL,
    comments TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (appointment_id) REFERENCES Appointments(appointment_id) ON DELETE CASCADE
    -- Patient and Doctor IDs can be retrieved via a JOIN with Appointments
);

-- Bonus: Waitlist
CREATE TABLE Waitlist (
    waitlist_id INT AUTO_INCREMENT PRIMARY KEY,
    doctor_id INT NOT NULL,
    patient_id INT NOT NULL,
    specialization_id INT, -- Added to allow waitlisting for a specialization
    requested_time DATETIME NOT NULL,
    status ENUM('waiting', 'notified', 'booked', 'cancelled') DEFAULT 'waiting',
    priority ENUM('high', 'medium', 'low') DEFAULT 'medium', -- Added priority
    notes TEXT, -- Added for additional information
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (doctor_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (patient_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (specialization_id) REFERENCES Specializations(specialization_id) ON DELETE SET NULL
);

-- Add indexes for common lookups for performance
CREATE INDEX idx_users_email ON Users (email);
CREATE INDEX idx_availability_doctor_time ON Availability (doctor_id, start_time, end_time);
CREATE INDEX idx_appointments_patient_doctor ON Appointments (patient_id, doctor_id);
CREATE INDEX idx_appointments_status ON Appointments (status);
CREATE INDEX idx_notifications_user ON Notifications (user_id);
CREATE INDEX idx_audit_logs_user_action ON Audit_Logs (user_id, action);


-- 2. Sample Data (DML) - Adjusted for new schema

-- Add doctors and patients with dummy password_hash
-- In a real app, these would be securely generated
INSERT INTO Users (user_type, first_name, last_name, email, password_hash, phone, date_of_birth, gender, status) VALUES
('doctor', 'Alice', 'Smith', 'alice.smith@telehealth.com', 'hashed_pass_alice', '9876543210', NULL, NULL, 'active'),
('doctor', 'Bob', 'Jones', 'bob.jones@telehealth.com', 'hashed_pass_bob',  '9988776655', NULL, NULL, 'active'),
('patient', 'Charlie', 'Brown', 'charlie.brown@telehealth.com', 'hashed_pass_charlie',  '9123456789', '1995-09-23', 'male', 'active');

-- Add specializations
INSERT INTO Specializations (name) VALUES
('Cardiology'), ('Dermatology'), ('General Medicine');

-- Associate doctors with specializations
INSERT INTO Doctor_Specializations (doctor_id, specialization_id) VALUES
((SELECT user_id FROM Users WHERE email = 'alice.smith@telehealth.com'), (SELECT specialization_id FROM Specializations WHERE name = 'Cardiology')),
((SELECT user_id FROM Users WHERE email = 'bob.jones@telehealth.com'), (SELECT specialization_id FROM Specializations WHERE name = 'Dermatology')),
((SELECT user_id FROM Users WHERE email = 'alice.smith@telehealth.com'), (SELECT specialization_id FROM Specializations WHERE name = 'General Medicine'));

INSERT INTO Availability (doctor_id, start_time, end_time, timezone) VALUES
((SELECT user_id FROM Users WHERE email = 'alice.smith@telehealth.com'), '2025-06-23 10:00:00', '2025-06-23 11:00:00', 'Asia/Kolkata'),
((SELECT user_id FROM Users WHERE email = 'bob.jones@telehealth.com'), '2025-06-23 14:00:00', '2025-06-23 15:00:00', 'Asia/Kolkata'),
((SELECT user_id FROM Users WHERE email = 'alice.smith@telehealth.com'), '2025-06-24 09:00:00', '2025-06-24 10:00:00', 'Asia/Kolkata'),
((SELECT user_id FROM Users WHERE email = 'alice.smith@telehealth.com'),'2025-06-24 10:00:00', '2025-06-24 11:00:00', 'Asia/Kolkata'),
((SELECT user_id FROM Users WHERE email = 'alice.smith@telehealth.com'),'2025-06-24 11:00:00', '2025-06-24 12:00:00', 'Asia/Kolkata'),
((SELECT user_id FROM Users WHERE email = 'alice.smith@telehealth.com'),'2025-06-25 09:00:00', '2025-06-25 10:00:00', 'Asia/Kolkata'); 

-- Book an appointment (using the first availability slot)
INSERT INTO Appointments (patient_id, doctor_id, availability_id, status) VALUES
((SELECT user_id FROM Users WHERE email = 'charlie.brown@telehealth.com'), (SELECT user_id FROM Users WHERE email = 'alice.smith@telehealth.com'), (SELECT availability_id FROM Availability WHERE start_time = '2025-06-23 10:00:00' AND doctor_id = (SELECT user_id FROM Users WHERE email = 'alice.smith@telehealth.com')), 'scheduled');

-- Generate virtual link
INSERT INTO Virtual_Links (appointment_id, meeting_url, expires_at) VALUES
((SELECT appointment_id FROM Appointments WHERE patient_id = 
                      (SELECT user_id FROM Users WHERE email = 'charlie.brown@telehealth.com')
                      AND doctor_id = (SELECT user_id 
                               FROM Users WHERE email = 'alice.smith@telehealth.com')
                               AND status = 'scheduled' LIMIT 1), 
                               'https://meet.telehealth.com/abc123', '2025-06-23 11:00:00');

-- Add consultation record
INSERT INTO Consultations (appointment_id, notes, prescription, outcome) VALUES
((SELECT appointment_id FROM Appointments WHERE patient_id = (SELECT user_id FROM Users WHERE email = 'charlie.brown@telehealth.com') AND doctor_id = (SELECT user_id FROM Users WHERE email = 'alice.smith@telehealth.com') AND status = 'scheduled' LIMIT 1), 'Patient reports chest pain.', 'Aspirin 75mg daily', 'Follow-up in 1 week');

-- Send notification
INSERT INTO Notifications (user_id, appointment_id, type, status, sent_at) VALUES
((SELECT user_id FROM Users WHERE email = 'charlie.brown@telehealth.com'), (SELECT appointment_id FROM Appointments WHERE patient_id = (SELECT user_id FROM Users WHERE email = 'charlie.brown@telehealth.com') AND doctor_id = (SELECT user_id FROM Users WHERE email = 'alice.smith@telehealth.com') AND status = 'scheduled' LIMIT 1), 'reminder', 'sent', '2025-06-22 18:00:00');

-- Log action
INSERT INTO Audit_Logs (user_id, action, target_table, target_id, details) VALUES
((SELECT user_id FROM Users WHERE email = 'charlie.brown@telehealth.com'), 'create', 'Appointments', (SELECT appointment_id FROM Appointments WHERE patient_id = (SELECT user_id FROM Users WHERE email = 'charlie.brown@telehealth.com') AND doctor_id = (SELECT user_id FROM Users WHERE email = 'alice.smith@telehealth.com') AND status = 'scheduled' LIMIT 1), 'Patient booked appointment with Dr. Alice Smith');

-- Bonus: Feedback
INSERT INTO Feedback (appointment_id, rating, comments) VALUES
((SELECT appointment_id FROM Appointments WHERE patient_id = (SELECT user_id FROM Users WHERE email = 'charlie.brown@telehealth.com') AND doctor_id = (SELECT user_id FROM Users WHERE email = 'alice.smith@telehealth.com') AND status = 'scheduled' LIMIT 1), 5, 'Very helpful and professional!');

-- Bonus: Waitlist
INSERT INTO Waitlist (doctor_id, patient_id, requested_time) VALUES
((SELECT user_id FROM Users WHERE email = 'bob.jones@telehealth.com'), (SELECT user_id FROM Users WHERE email = 'charlie.brown@telehealth.com'), '2025-06-24 14:00:00');


-- 3. Core SQL Queries and Procedures - Wrapped in transactions for atomicity

-- a. Book Appointment (Atomic Operation)
DELIMITER //
CREATE PROCEDURE BookAppointment(
    IN p_patient_id INT,
    IN p_doctor_id INT,
    IN p_availability_id INT,
    IN p_meeting_url_prefix VARCHAR(255), -- e.g., 'https://meet.telehealth.com/'
    IN p_expires_at DATETIME,
    IN p_log_details TEXT
)
BEGIN
    DECLARE v_appointment_id INT;
    DECLARE v_is_slot_available BOOLEAN;

    START TRANSACTION;

    -- Step 1: Check if the availability slot is truly available (not already booked)
    -- This relies on the UNIQUE (availability_id) constraint in Appointments
    SELECT COUNT(*) INTO v_is_slot_available
    FROM Appointments
    WHERE availability_id = p_availability_id;

    IF v_is_slot_available = 0 THEN
        -- Step 2: Book the appointment
        INSERT INTO Appointments (patient_id, doctor_id, availability_id, status)
        VALUES (p_patient_id, p_doctor_id, p_availability_id, 'scheduled');

        SET v_appointment_id = LAST_INSERT_ID();

        -- Step 3: Generate virtual link
        INSERT INTO Virtual_Links (appointment_id, meeting_url, expires_at)
        VALUES (v_appointment_id, CONCAT(p_meeting_url_prefix, UUID()), p_expires_at);

        -- Step 4: Log the action
        INSERT INTO Audit_Logs (user_id, action, target_table, target_id, details)
        VALUES (p_patient_id, 'create', 'Appointments', v_appointment_id, p_log_details);

        COMMIT;
        SELECT 'Appointment booked successfully.' AS message, v_appointment_id AS new_appointment_id;
    ELSE
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Appointment slot is already booked or invalid.';
    END IF;

END //
DELIMITER ;

-- Example Call (from application):
CALL BookAppointment(3, 1, 1, 'https://meet.telehealth.com/', '2025-06-23 11:00:00', 'Patient Charlie Brown booked appointment with Dr. Alice Smith.');


-- b. Reschedule Appointment (Atomic Operation)
DELIMITER //
CREATE PROCEDURE RescheduleAppointment(
    IN p_appointment_id INT,
    IN p_new_availability_id INT,
    IN p_rescheduling_user_id INT, -- User performing the reschedule (patient or doctor)
    IN p_log_details TEXT
)
BEGIN
    DECLARE v_old_availability_id INT;
    DECLARE v_is_slot_available BOOLEAN;

    START TRANSACTION;

    -- Step 1: Get the current availability_id for the appointment
    SELECT availability_id INTO v_old_availability_id
    FROM Appointments
    WHERE appointment_id = p_appointment_id
    FOR UPDATE; -- Lock the row to prevent race conditions

    -- Step 2: Check if the new availability slot is truly available
    SELECT COUNT(*) INTO v_is_slot_available
    FROM Appointments
    WHERE availability_id = p_new_availability_id;

    IF v_old_availability_id IS NOT NULL AND v_is_slot_available = 0 THEN
        -- Step 3: Update the appointment with the new availability
        UPDATE Appointments
        SET status = 'rescheduled', availability_id = p_new_availability_id
        WHERE appointment_id = p_appointment_id;

        -- Step 4: Generate new virtual link (optional, if each reschedule gets a new link)
        -- Or just update the existing one
        UPDATE Virtual_Links
        SET meeting_url = CONCAT('https://meet.telehealth.com/', UUID()),
            expires_at = (SELECT end_time FROM Availability WHERE availability_id = p_new_availability_id)
        WHERE appointment_id = p_appointment_id;

        -- Step 5: Log the action
        INSERT INTO Audit_Logs (user_id, action, target_table, target_id, details)
        VALUES (p_rescheduling_user_id, 'reschedule', 'Appointments', p_appointment_id, p_log_details);

        -- Step 6: Send notification (application would handle actual sending)
        INSERT INTO Notifications (user_id, appointment_id, type, status, sent_at)
        SELECT patient_id, p_appointment_id, 'reschedule_confirm', 'pending', NOW() FROM Appointments WHERE appointment_id = p_appointment_id;

        COMMIT;
        SELECT 'Appointment rescheduled successfully.' AS message;
    ELSE
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Appointment not found or new slot is already booked/invalid.';
    END IF;

END //
DELIMITER ;

-- Example Call (from application):
CALL RescheduleAppointment(1, 3, 3, 'Appointment 1 rescheduled by patient Charlie Brown to a new slot.');


-- c. Cancel Appointment (Atomic Operation)
DELIMITER //
CREATE PROCEDURE CancelAppointment(
    IN p_appointment_id INT,
    IN p_cancelling_user_id INT, -- User performing the cancellation (patient or doctor)
    IN p_log_details TEXT
)
BEGIN
    DECLARE v_current_status ENUM('scheduled', 'completed', 'cancelled', 'rescheduled');

    START TRANSACTION;

    -- Step 1: Get current status and lock the row
    SELECT status INTO v_current_status
    FROM Appointments
    WHERE appointment_id = p_appointment_id
    FOR UPDATE;

    IF v_current_status IS NOT NULL AND v_current_status IN ('scheduled', 'rescheduled') THEN
        -- Step 2: Update the appointment status to cancelled
        UPDATE Appointments
        SET status = 'cancelled'
        WHERE appointment_id = p_appointment_id;

        -- Step 3: Log the action
        INSERT INTO Audit_Logs (user_id, action, target_table, target_id, details)
        VALUES (p_cancelling_user_id, 'cancel', 'Appointments', p_appointment_id, p_log_details);

        -- Step 4: Send cancellation notification
        INSERT INTO Notifications (user_id, appointment_id, type, status, sent_at)
        SELECT patient_id, p_appointment_id, 'cancellation', 'pending', NOW() FROM Appointments WHERE appointment_id = p_appointment_id;

        COMMIT;
        SELECT 'Appointment cancelled successfully.' AS message;
    ELSE
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Appointment not found or cannot be cancelled (e.g., already completed).';
    END IF;

END //
DELIMITER ;

-- Example Call (from application):
-- CALL CancelAppointment(1, 3, 'Patient Charlie Brown cancelled appointment 1.');


-- d. Get Doctor’s Available Slots: (Adjusted for removal of is_booked)
SELECT av.availability_id, av.start_time, av.end_time, av.timezone,
u.first_name as doctor_first_name,
u.last_name as doctor_last_name
FROM Availability av
JOIN users u ON av.doctor_id = u.user_id
LEFT JOIN Appointments a ON av.availability_id = a.availability_id
WHERE av.doctor_id = 1
  AND a.availability_id IS NULL -- This means the slot is NOT booked
  AND av.start_time > NOW();

-- For Alice
SELECT av.availability_id, av.start_time, av.end_time, av.timezone
FROM Availability av
LEFT JOIN Appointments a ON av.availability_id = a.availability_id
WHERE av.doctor_id = 1
  AND a.availability_id IS NULL
 

-- e. Record Consultation:
DELIMITER //
CREATE PROCEDURE RecordConsultation(
    IN p_appointment_id INT,
    IN p_notes TEXT,
    IN p_prescription TEXT,
    IN p_outcome TEXT,
    IN p_recording_user_id INT
)
BEGIN
    DECLARE v_consultation_id INT;
    DECLARE v_doctor_id INT;

    START TRANSACTION;

    -- Get the doctor_id associated with the appointment for logging
    SELECT doctor_id INTO v_doctor_id
    FROM Appointments
    WHERE appointment_id = p_appointment_id;

    IF v_doctor_id IS NOT NULL THEN
        INSERT INTO Consultations (appointment_id, notes, prescription, outcome)
        VALUES (p_appointment_id, p_notes, p_prescription, p_outcome);

        SET v_consultation_id = LAST_INSERT_ID();

        INSERT INTO Audit_Logs (user_id, action, target_table, target_id, details)
        VALUES (p_recording_user_id, 'create', 'Consultations', v_consultation_id, CONCAT('Consultation recorded for appointment ', p_appointment_id));

        -- Optionally update appointment status to 'completed'
        UPDATE Appointments SET status = 'completed' WHERE appointment_id = p_appointment_id;

        COMMIT;
        SELECT 'Consultation recorded successfully.' AS message;
    ELSE
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Appointment not found or invalid.';
    END IF;

END //
DELIMITER ;

-- Example Call (from application):
-- CALL RecordConsultation(1, 'Patient feels better.', 'No new medication.', 'Resolved.', 1);

SELECT appointment_id, patient_id, doctor_id, availability_id, status FROM Appointments;
-- f. Send Notification: (As a stored procedure for better control)
DELIMITER //
CREATE PROCEDURE SendNotification(
    IN p_user_id INT,
    IN p_appointment_id INT,
    IN p_type ENUM('reminder', 'confirmation', 'cancellation', 'reschedule_confirm'),
    IN p_status ENUM('pending', 'sent', 'failed')
)
BEGIN
    INSERT INTO Notifications (user_id, appointment_id, type, status, sent_at)
    VALUES (p_user_id, p_appointment_id, p_type, p_status, NOW());
    SELECT 'Notification logged successfully.' AS message;
END //
DELIMITER ;

-- Example Call (from application):
CALL SendNotification((select user_id from users where email='charlie.brown@telehealth.com'),
 2, 'reminder', 'sent');


-- g. List Patient Appointments: (Adjusted to get start_time from Availability)
SELECT
    a.appointment_id,
    a.patient_id,
    a.doctor_id,
    a.status,
    a.created_at,
    a.updated_at,
    d.first_name AS doctor_first_name,
    d.last_name AS doctor_last_name,
    av.start_time AS appointment_start_time, -- Get actual start time from Availability
    av.end_time AS appointment_end_time,     -- Get actual end time from Availability
    av.timezone,
    v.meeting_url
FROM Appointments a
JOIN Users d ON a.doctor_id = d.user_id
JOIN Availability av ON a.availability_id = av.availability_id -- Join to get time details
LEFT JOIN Virtual_Links v ON a.appointment_id = v.appointment_id
WHERE a.patient_id = (select user_id from users where email = 'charlie.brown@telehealth.com');

-- Example Query
-- SELECT
--     a.appointment_id,
--     a.patient_id,
--     a.doctor_id,
--     a.status,
--     a.created_at,
--     a.updated_at,
--     d.first_name AS doctor_first_name,
--     d.last_name AS doctor_last_name,
--     av.start_time AS appointment_start_time,
--     av.end_time AS appointment_end_time,
--     av.timezone,
--     v.meeting_url
-- FROM Appointments a
-- JOIN Users d ON a.doctor_id = d.user_id
-- JOIN Availability av ON a.availability_id = av.availability_id
-- LEFT JOIN Virtual_Links v ON a.appointment_id = v.appointment_id
-- WHERE a.patient_id = 3;

-- Fetching the average rating for each doctor
SELECT
    d.user_id AS doctor_id,
    d.first_name AS doctor_first_name,
    d.last_name AS doctor_last_name,
    COUNT(f.feedback_id) AS total_feedback_received,
    ROUND(AVG(f.rating), 2) AS average_rating -- Rounds to 2 decimal places
FROM
    Users d
JOIN
    Appointments a ON d.user_id = a.doctor_id
JOIN
    Feedback f ON a.appointment_id = f.appointment_id
WHERE
    d.user_type = 'doctor' -- Ensure we're only looking at doctors
GROUP BY
    d.user_id, d.first_name, d.last_name
ORDER BY
    average_rating DESC; -- Order by highest average rating first;
    
    -- Getting the feedback of for specific appointment
SELECT
    a.appointment_id,
    p.first_name AS patient_first_name,
    p.last_name AS patient_last_name,
    f.rating,
    f.comments,
    f.created_at AS feedback_date,
    av.start_time AS appointment_time
FROM
    Feedback f
JOIN
    Appointments a ON f.appointment_id = a.appointment_id
JOIN
    Users d ON a.doctor_id = d.user_id
JOIN
    Users p ON a.patient_id = p.user_id -- Join again to get patient's name
JOIN
    Availability av ON a.availability_id = av.availability_id -- To get appointment time
WHERE
    d.user_id = (SELECT user_id FROM Users WHERE email = 'alice.smith@telehealth.com') -- Replace with specific doctor_id or a subquery
ORDER BY
    f.created_at DESC;