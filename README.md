# DevifyX-MySQL-Core-Job-Assignment
Overview of  Telehealth Database Schema which lets the patient book a session with the doctors and let the doctor fill their availability slot.
It defines a robust relational database for a telehealth platform. It covers essential entities and their relationships, including:

Users: A unified table for both patients and doctors, distinguished by user_type. It includes fields for authentication (password_hash) and user status.

Specializations: Defines medical fields.

Doctor_Specializations: A many-to-many relationship table, allowing doctors to have multiple specializations.

Availability: Stores time slots when doctors are available, ensuring unique slots per doctor.

Appointments: Records bookings between patients and doctors, linked to specific availability slots. Crucially, it infers booking status from the existence of an appointment for a given availability_id.

Virtual_Links: Stores unique video call URLs for each appointment.

Consultations: Detailed records of completed medical consultations, linked one-to-one with appointments.

Notifications: Tracks system notifications (reminders, confirmations, etc.) sent to users.

Audit_Logs: A valuable table for tracking significant actions within the system, enhancing security and accountability.

Recurring_Appointments (Bonus): A table to define patterns for recurring appointments.

Feedback (Bonus): Stores patient ratings and comments for appointments.

Waitlist (Bonus): Manages patients waiting for a doctor or specialization, including priority and notes.

The schema also includes indexes on frequently queried columns to improve performance.

Key Strengths and Good Practices
Clear Table Naming and Relationships: The table names are intuitive, and FOREIGN KEY constraints are correctly established, including appropriate ON DELETE actions (CASCADE, RESTRICT, SET NULL).

Unified User Table: Using a single Users table with a user_type enum simplifies user management and authentication across the platform.

Enum Types: Extensive use of ENUM types (user_type, gender, status in Users, status in Appointments/Notifications/Waitlist, type in Notifications, recurrence_pattern, priority) ensures data consistency and limits valid values.

Transaction Management in Stored Procedures: The BookAppointment, RescheduleAppointment, and CancelAppointment procedures correctly use START TRANSACTION and COMMIT/ROLLBACK, ensuring atomicity. This is crucial for maintaining data integrity during complex operations.

Audit Logging: The Audit_Logs table is an excellent addition for tracing actions, which is vital for security, debugging, and compliance.

Comprehensive Core Procedures: The provided procedures cover the most common and critical operations: booking, rescheduling, and cancelling appointments, and recording consultations.

Bonus Tables: The Recurring_Appointments, Feedback, and Waitlist tables add significant value and extend the functionality of the telehealth system.


Overall, this is a solid foundation for a telehealth database. The careful consideration of relationships, data types, and transactional integrity makes it a well-designed system.
