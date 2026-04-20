import os
from flask import send_from_directory, request
import sys

# Manually point to the folder you just pasted
model_path = r'C:\Users\user\AppData\Local\Programs\Python\Python312\Lib\site-packages\face_recognition\models'
os.environ['FACE_RECOGNITION_MODELS'] = model_path

# Add the site-packages to the system path just to be safe
sys.path.append(r'C:\Users\user\AppData\Local\Programs\Python\Python312\Lib\site-packages')

import random
from collections import deque
from flask import Flask, request, jsonify
from flask_cors import CORS
import psycopg2
from werkzeug.security import generate_password_hash, check_password_hash
import face_recognition
import base64
import io
import numpy as np
import cv2 # Ensure opencv-python is installed
from datetime import date

app = Flask(__name__)
CORS(app)

# --- ADD THESE LINES TO FIX THE "UPLOAD_FOLDER" ERROR ---
UPLOAD_FOLDER = 'uploads'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
# -------------------------------------------------------

# ---------------- DATABASE CONNECTION ----------------
conn = psycopg2.connect(
    host="localhost",
    database="facegate",
    user="postgres",
    password="postgresexamauthdb" # Change this to 'postgresexamauthdb' if needed
)
cursor = conn.cursor()

UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# --- 1. REGISTER STUDENT (FIXED) ---
@app.route("/register/student", methods=["POST"])
def register_student():
    try:
        data = request.form
        photo = request.files.get("photo")

        # Required fields check
        required = ["name", "email", "password", "register_number", "department"]
        if not all(k in data for k in required) or not photo:
            return jsonify({"error": "All fields including photo are required"}), 400

        # Check if email exists
        cursor.execute("SELECT id FROM users WHERE email=%s", (data['email'],))
        if cursor.fetchone():
            return jsonify({"error": "Email already exists"}), 400

        # Step A: Insert into generic 'users' table 
        # FIXED: Added 'name' here so the dashboard can find it!
        password_hash = generate_password_hash(data['password'], method='scrypt')
        cursor.execute(
            "INSERT INTO users (name, email, password_hash, role) VALUES (%s, %s, %s, %s) RETURNING id",
            (data['name'], data['email'], password_hash, "student")
        )
        user_id = cursor.fetchone()[0]

        # Step B: Save Photo
        photo_path = os.path.join(app.config['UPLOAD_FOLDER'], f"student_{user_id}_{photo.filename}")
        photo.save(photo_path)

        # Step C: Insert into 'students' table
        cursor.execute("""
            INSERT INTO students (user_id, name, email, register_number, department, photo_path) 
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (user_id, data['name'], data['email'], data['register_number'], data['department'], photo_path))
        
        conn.commit()
        return jsonify({"message": "Student registered successfully"}), 201

    except Exception as e:
        conn.rollback()
        print(f"Error: {e}") 
        return jsonify({"error": str(e)}), 500

# --- 2. REGISTER STAFF ---
@app.route("/register/staff", methods=["POST"])
def register_staff():
    try:
        data = request.form
        photo = request.files.get("photo")

        required = ["name", "email", "password", "department", "phone", "dob"]
        if not all(k in data for k in required) or not photo:
            return jsonify({"error": "All fields including photo are required"}), 400

        cursor.execute("SELECT id FROM users WHERE email=%s", (data['email'],))
        if cursor.fetchone():
            return jsonify({"error": "Email already exists"}), 400

        password_hash = generate_password_hash(data['password'], method='scrypt')
        
        # FIXED: Added 'name' to the INSERT columns and values
        cursor.execute(
            "INSERT INTO users (email, password_hash, role, name) VALUES (%s, %s, %s, %s) RETURNING id",
            (data['email'], password_hash, "staff", data['name'])
        )
        user_id = cursor.fetchone()[0]

        photo_path = os.path.join(app.config['UPLOAD_FOLDER'], f"staff_{user_id}_{photo.filename}")
        photo.save(photo_path)

        cursor.execute("""
            INSERT INTO staff (user_id, name, email, department, phone, date_of_birth, photo_path) 
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (user_id, data['name'], data['email'], data['department'], data['phone'], data['dob'], photo_path))
        
        conn.commit()
        return jsonify({"message": "Staff registered successfully"}), 201

    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500

# ---------------- LOGIN ----------------
@app.route("/login", methods=["POST"])
def login():
    try:
        data = request.json
        email = data.get("email")
        password = data.get("password")

        cursor.execute("SELECT id, password_hash, role FROM users WHERE email=%s", (email,))
        user = cursor.fetchone()
        if not user or not check_password_hash(user[1], password):
            return jsonify({"error": "Invalid credentials"}), 401

        user_id, _, role = user
        profile = {}

        if role == "student":
            # UPDATED: Added dashboard_pic to the SELECT query
            cursor.execute("""
                SELECT user_id, name, email, register_number, photo_path, profile_completed, dashboard_pic 
                FROM students WHERE user_id=%s
            """, (user_id,))
            student = cursor.fetchone()
            profile = {
                "user_id": student[0],
                "name": student[1],
                "email": student[2],
                "register_number": student[3],
                "photo_path": student[4], # Face Recognition (Keep this untouched)
                "profile_completed": student[5],
                "dashboard_pic": student[6] # The new Display Picture
            }
        elif role == "staff":
            cursor.execute("SELECT user_id, name, email, department, phone, date_of_birth FROM staff WHERE user_id=%s", (user_id,))
            staff = cursor.fetchone()
            profile = {
                "user_id": staff[0], 
                "name": staff[1], 
                "email": staff[2],
                "department": staff[3],
                "phone": staff[4],
                "date_of_birth": str(staff[5]) if staff[5] else None
            }
        elif role == "admin":
            cursor.execute("SELECT user_id, name, email FROM admin WHERE user_id=%s", (user_id,))
            admin = cursor.fetchone()
            if admin:
                profile = {
                    "user_id": admin[0],
                    "name": admin[1],
                    "email": admin[2]
                }
            else:
                profile = {"user_id": user_id, "name": "System Admin", "email": email}

        return jsonify({"role": role, "user_id": user_id, "profile": profile}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ==================================================
# ================ ADMIN INTERFACE API =============

# --- 1. Get all Students and Staff for the list ---
##

# ---------------- COMPLETE PROFILE ----------------
@app.route("/complete-profile/<int:user_id>", methods=["POST"])
def complete_profile(user_id):
    try:
        data = request.json
        cursor.execute("""
            UPDATE students 
            SET department = %s, course_type = %s, date_of_birth = %s, phone = %s, profile_completed = TRUE
            WHERE user_id = %s
        """, (data.get("department"), data.get("course_type"), data.get("dob"), data.get("phone"), user_id))
        conn.commit()
        return jsonify({"message": "Profile completed"}), 200
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 50
# ==================================================
# ================ ADD SEMESTER DATA ===============
# ==================================================
@app.route("/add-semester-subject/<int:user_id>", methods=["POST"])
def add_semester_subject(user_id):
    try:
        data = request.json
        
        # --- DATA CLEANING ---
        subj_code_clean = data['subject_code'].strip().upper()
        dept_clean = data['department'].strip().upper()
        subj_name_clean = data['subject_name'].strip().capitalize()
        sem_clean = int(data['semester'])
        # ---------------------

        # 1. Get student's internal ID
        cursor.execute("SELECT id FROM students WHERE user_id = %s", (user_id,))
        student_row = cursor.fetchone()
        if not student_row:
            return jsonify({"error": "Student not found"}), 404
        student_id = student_row[0]

        # 2. Check if this subject already exists (IMPROVED: Case-insensitive search)
        cursor.execute("""
            SELECT id FROM subjects 
            WHERE UPPER(TRIM(subject_code)) = %s 
            AND UPPER(TRIM(department)) = %s 
            AND semester = %s
        """, (subj_code_clean, dept_clean, sem_clean))
        
        existing_subject = cursor.fetchone()

        if existing_subject:
            subject_id = existing_subject[0]
            # Update the exam date/center if they changed
            cursor.execute("""
                UPDATE subjects 
                SET exam_date = %s, exam_center = %s 
                WHERE id = %s
            """, (data['exam_date'], data['exam_center'], subject_id))
        else:
            # 3. Insert new subject using cleaned data
            cursor.execute("""
                INSERT INTO subjects (subject_name, subject_code, department, semester, exam_date, exam_center)
                VALUES (%s, %s, %s, %s, %s, %s) RETURNING id
            """, (
                subj_name_clean, 
                subj_code_clean, 
                dept_clean, 
                sem_clean, 
                data['exam_date'], 
                data['exam_center']
            ))
            subject_id = cursor.fetchone()[0]

        # 4. Link student to subject (Using the unique Subject ID)
        # Added ON CONFLICT to handle cases where student tries to register twice
        cursor.execute("""
            INSERT INTO student_subjects (
                student_id, subject_id, subject_name, subject_code, department, semester, exam_date, exam_center
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (student_id, subject_id) DO NOTHING
        """, (
            student_id, 
            subject_id, 
            subj_name_clean, 
            subj_code_clean, 
            dept_clean,
            sem_clean, 
            data['exam_date'], 
            data['exam_center']
        ))

        conn.commit()
        return jsonify({"message": "Semester details processed successfully"}), 201
    except Exception as e:
        conn.rollback()
        print(f"Detailed DB Error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/get-student-subjects/<int:user_id>", methods=["GET"])
def get_student_subjects(user_id):
    try:
        # First, find the student's internal ID
        cursor.execute("SELECT id FROM students WHERE user_id = %s", (user_id,))
        student_row = cursor.fetchone()
        if not student_row:
            return jsonify([]), 200 # Return empty list if student doesn't exist yet

        student_id = student_row[0]

        # Fetch all subjects linked to this student
        # We order by semester and subject_name to keep it neat
        cursor.execute("""
            SELECT semester, subject_name, subject_code, exam_date, exam_center, department
            FROM student_subjects
            WHERE student_id = %s
            ORDER BY semester DESC, subject_name ASC
        """, (student_id,))
        
        rows = cursor.fetchall()
        
        # Convert list of tuples into a list of dictionaries for Flutter
        subjects = []
        for r in rows:
            subjects.append({
                "semester": r[0],
                "subject_name": r[1],
                "subject_code": r[2],
                "exam_date": r[3],
                "exam_center": r[4],
                "department": r[5]
            })

        return jsonify(subjects), 200

    except Exception as e:
        print(f"Error fetching subjects: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/delete-student-subject/<int:user_id>/<string:subject_code>", methods=["DELETE"])
def delete_student_subject(user_id, subject_code):
    try:
        # Get student internal ID
        cursor.execute("SELECT id FROM students WHERE user_id = %s", (user_id,))
        student_id = cursor.fetchone()[0]

        # Delete from student_subjects table
        cursor.execute("""
            DELETE FROM student_subjects 
            WHERE student_id = %s AND subject_code = %s
        """, (student_id, subject_code))
        
        conn.commit()
        return jsonify({"message": "Subject removed"}), 200
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500





# ==================================================
# ============ GET EXAM HALL DETAILS ==============
# ==================================================

# ----------------EXAM HALL ARRANGEMENTS ----------------
@app.route("/exam-hall-arrangements/<int:user_id>", methods=["GET"])
def get_exam_hall_arrangements(user_id):
    try:
        # 🔥 IMPORTANT FIX:
        # allocations.student_id stores users.id
        real_student_id = user_id

        # 1️⃣ Check if THIS user has allocation
        cursor.execute("SELECT COUNT(*) FROM allocations WHERE student_id = %s", (real_student_id,))
        is_registered = cursor.fetchone()[0] > 0

        if not is_registered:
            return jsonify({"status": "no_exam", "message": "You have no exams today"}), 200

        # 2️⃣ Fetch ALL students for that exam
        query = """
            SELECT 
                u_std.name AS student_name,
                c.room_name,
                a.seat_number,
                u_staff.name AS staff_name
            FROM allocations a
            LEFT JOIN users u_std ON a.student_id = u_std.id
            LEFT JOIN classrooms c ON a.room_id = c.id
            LEFT JOIN users u_staff ON a.staff_id = u_staff.id
            ORDER BY u_std.name ASC
        """
        cursor.execute(query)
        rows = cursor.fetchall()
        
        results = []
        for r in rows:
            results.append({
                "name": r[0] if r[0] else "Unnamed",
                "room": r[1] if r[1] else "—",
                "seat": r[2] if r[2] else "—",
                "staff": r[3] if r[3] else "TBA"
            })
            
        return jsonify({"status": "success", "data": results}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500




# ADD THIS: This route lets Flutter download the photo from your 'uploads' folder
@app.route('/uploads/<path:filename>')
def serve_student_photo(filename):
    # This assumes your photos are in a folder named 'uploads' in your project root
    return send_from_directory('uploads', filename)


# ==================================================
# ================ STAFF INTERFACE API =============
# ==================================================

# 1. Staff Profile Details (Updated for naming consistency)
@app.route("/staff-profile-full/<int:user_id>", methods=["GET"])
def get_staff_full_profile(user_id):
    try:
        # We select: photo_path(0), name(1), email(2), department(3), phone(4), date_of_birth(5)
        cursor.execute("""
            SELECT photo_path, name, email, department, phone, date_of_birth 
            FROM staff WHERE user_id = %s
        """, (user_id,))
        s = cursor.fetchone()
        
        if not s: 
            return jsonify({"error": "Staff profile not found"}), 404
            
        return jsonify({
            "photo_path": s[0], 
            "name": s[1], 
            "email": s[2], 
            "department": s[3],      # Changed from 'dept' to match Flutter
            "phone": s[4], 
            "date_of_birth": str(s[5]) if s[5] else None  # Changed from 'dob' to match Flutter
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500



@app.route("/staff-room-students/<int:user_id>", methods=["GET"])
def get_staff_room_students(user_id):
    print(f"\n--- DEBUG: Fetching Room Data for Staff ID: {user_id} ---")
    
    try:
        # 1. Fetch Staff Name and Notes
        cursor.execute("SELECT name, notes FROM staff WHERE user_id = %s", (user_id,))
        staff_data = cursor.fetchone()
        staff_name = staff_data[0] if staff_data else "Unknown Staff"
        notes = staff_data[1] if staff_data and staff_data[1] else ""

        # 2. Find which room this staff member is assigned to
        cursor.execute("SELECT room_id FROM allocations WHERE staff_id = %s LIMIT 1", (user_id,))
        alloc_row = cursor.fetchone()
        
        if not alloc_row:
            return jsonify({
                "room_name": "No Room Found",
                "staff_name": staff_name,
                "students": [],
                "notes": notes
            }), 200
        
        room_id = alloc_row[0]

        # 3. Get the Room Name
        cursor.execute("SELECT room_name FROM classrooms WHERE id = %s", (room_id,))
        room_result = cursor.fetchone()
        room_name = room_result[0] if room_result else "Unknown Room"

        # 4. Fetch ALL Students with their real-time status
        cursor.execute("""
            SELECT 
                a.id, 
                u.name, 
                a.seat_number, 
                s.register_number, 
                sub.subject_name,
                a.status
            FROM allocations a
            JOIN users u ON a.student_id = u.id
            LEFT JOIN students s ON u.id = s.user_id
            JOIN exams e ON a.exam_id = e.id
            JOIN subjects sub ON e.subject_id = sub.id
            WHERE a.room_id = %s AND a.staff_id = %s
            ORDER BY CAST(SUBSTRING(a.seat_number FROM '[0-9]+') AS INTEGER) ASC
        """, (room_id, user_id))
        
        rows = cursor.fetchall()

        students_list = []
        for r in rows:
            students_list.append({
                "allocation_id": r[0],
                "name": r[1],
                "seat_number": r[2],
                "register_number": r[3],
                "exam_name": r[4],
                "status": r[5] if r[5] else "Absent" # Status pulled directly from DB
            })
        
        return jsonify({
            "room_name": room_name,
            "staff_name": staff_name,
            "students": students_list,
            "notes": notes
        }), 200

    except Exception as e:
        print(f"🔥 ERROR: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route("/update-staff-notes", methods=["POST"])
def update_staff_notes():
    data = request.json
    user_id = data.get('user_id')
    # Use .get() without extra logic so we catch the empty string ""
    new_notes = data.get('notes') 

    if user_id is None:
        return jsonify({"error": "User ID is missing"}), 400

    try:
        # FORCE the update regardless of whether new_notes is "Hello" or ""
        # We don't use 'if new_notes:' because that skips empty strings!
        cursor.execute("""
            UPDATE staff 
            SET notes = %s 
            WHERE user_id = %s
        """, (new_notes, user_id))
        
        conn.commit()
        
        # This print will tell you the truth in your terminal
        print(f"DEBUG: Notes for {user_id} updated to: '{new_notes}'")

        return jsonify({"message": "Success"}), 200

    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"error": str(e)}), 500
# --- FACE RECOGNITION  ---

@app.route("/verify-face-attendance", methods=["POST"])
def verify_face():
    try:
        data = request.json
        reg_no = str(data.get("register_number", "")).strip()
        image_base64 = data.get("image_base64")
        staff_id = data.get("staff_id")

        if "," in image_base64:
            image_base64 = image_base64.split(",")[1]

        img_bytes = base64.b64decode(image_base64)
        nparr = np.frombuffer(img_bytes, np.uint8)
        unknown_image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        unknown_image = cv2.cvtColor(unknown_image, cv2.COLOR_BGR2RGB)

        cursor.execute(
            "SELECT user_id, photo_path FROM students WHERE register_number = %s",
            (reg_no,)
        )
        result = cursor.fetchone()

        if not result or not result[1]:
            return jsonify({"success": False, "message": "Student record not found"}), 404

        student_id = result[0]
        photo_path = result[1]

        known_image = face_recognition.load_image_file(photo_path)
        known_encs = face_recognition.face_encodings(known_image)
        unknown_encs = face_recognition.face_encodings(unknown_image)

        if not unknown_encs:
            return jsonify({"success": False, "message": "No face detected"}), 400

        face_dist = face_recognition.face_distance(
            [known_encs[0]], unknown_encs[0]
        )[0]

        if face_dist <= 0.5:

            query = """
                SELECT a.exam_id
                FROM allocations a
                WHERE a.student_id = %s AND a.staff_id = %s
                LIMIT 1
            """

            cursor.execute(query, (student_id, staff_id))
            snapshot = cursor.fetchone()

            if snapshot:
                e_id = snapshot[0]

                # 1️⃣ Update allocation status
                cursor.execute("""
                    UPDATE allocations 
                    SET status = 'PRESENT'
                    WHERE student_id = %s AND exam_id = %s
                """, (student_id, e_id))

                # 2️⃣ Update attendance history ONLY
                cursor.execute("""
                    UPDATE attendance_history
                    SET status = 'PRESENT'
                    WHERE student_id = %s AND exam_id = %s
                """, (student_id, e_id))

                conn.commit()
                return jsonify({"success": True, "message": f"Verified: {reg_no} ✅"}), 200

            else:
                return jsonify({"success": False, "message": "No allocation found"}), 404

        return jsonify({"success": False, "message": "Face mismatch"}), 400

    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({"success": False, "message": str(e)}), 500
# 4. Save Staff Note (Used in Edit/Update Screen)
@app.route("/save-staff-note", methods=["POST"])
def save_note():
    try:
        data = request.json
        # We fetch the primary staff ID using the user_id if needed
        cursor.execute("SELECT id FROM staff WHERE user_id = %s", (data['user_id'],))
        staff_id = cursor.fetchone()[0]

        cursor.execute("""
            INSERT INTO staff_notes (exam_id, staff_id, student_id, note_text) 
            VALUES (%s, %s, %s, %s)
        """, (data['exam_id'], staff_id, data.get('student_id'), data['note_text']))
        conn.commit()
        return jsonify({"message": "Note saved successfully"}), 201
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500

# ==================================================
# ================ ADMIN INTERFACE API =============

# 1. Fetch all registered Students and Staff
@app.route("/admin/all-users", methods=["GET"])
def get_all_users():
    try:
        # Get Students
        cursor.execute("SELECT user_id, name, email, register_number, department FROM students")
        students = [{"id": r[0], "name": r[1], "email": r[2], "reg_no": r[3], "dept": r[4], "role": "Student"} for r in cursor.fetchall()]
        
        # Get Staff
        cursor.execute("SELECT user_id, name, email, department FROM staff")
        staff = [{"id": r[0], "name": r[1], "email": r[2], "dept": r[3], "role": "Staff"} for r in cursor.fetchall()]
        
        return jsonify(students + staff), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# 2. Update user details from Admin panel
@app.route("/admin/update-user", methods=["POST"])
def admin_update_user():
    data = request.json
    try:
        if data['role'] == "Student":
            cursor.execute("""
                UPDATE students SET name=%s, email=%s, register_number=%s, department=%s WHERE user_id=%s
            """, (data['name'], data['email'], data['reg_no'], data['dept'], data['id']))
        else:
            cursor.execute("""
                UPDATE staff SET name=%s, email=%s, department=%s WHERE user_id=%s
            """, (data['name'], data['email'], data['dept'], data['id']))
        conn.commit()
        return jsonify({"message": "User updated successfully!"}), 200
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500

# --- CLASSROOM SETUP ---
@app.route("/admin/add-room", methods=["POST"])
def add_room():
    data = request.json
    try:
        cursor.execute("INSERT INTO classrooms (room_number, capacity) VALUES (%s, %s)", 
                       (data['room_number'], data['capacity']))
        conn.commit()
        return jsonify({"message": "Room added"}), 201
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500

@app.route("/admin/rooms", methods=["GET"])
def get_rooms():
    cursor.execute("SELECT id, room_number, capacity, is_active FROM classrooms")
    rooms = [{"id": r[0], "room_number": r[1], "capacity": r[2], "is_active": r[3]} for r in cursor.fetchall()]
    return jsonify(rooms), 200

# --- EXAM MANAGEMENT ---
# --- 1. ADD EXAM ---


@app.route("/admin/add-exam", methods=["POST"])
def add_exam():
    data = request.json
    try:
        # --- DATA CLEANING ---
        subj_code_clean = data['subject_code'].strip().upper()
        dept_clean = data['department'].strip().upper()
        subj_name_clean = data['subject_name'].strip().capitalize()
        sem_clean = data['semester'].strip()   # 🔥 keep as string
        exam_date = data['exam_date']
        # ---------------------

        # 1️⃣ Check if subject already exists
        cursor.execute("""
            SELECT id FROM subjects 
            WHERE UPPER(subject_code) = %s 
            AND UPPER(department) = %s 
            AND semester = %s 
            LIMIT 1
        """, (subj_code_clean, dept_clean, sem_clean))
        
        subject_result = cursor.fetchone()

        if subject_result:
            sub_id = subject_result[0]
        else:
            cursor.execute("""
                INSERT INTO subjects (subject_name, subject_code, department, semester, exam_date)
                VALUES (%s, %s, %s, %s, %s) RETURNING id
            """, (subj_name_clean, subj_code_clean, dept_clean, sem_clean, exam_date))
            sub_id = cursor.fetchone()[0]

        # 2️⃣ Check if exam already exists
        cursor.execute("""
            SELECT id FROM exams
            WHERE subject_id = %s
            AND exam_date = %s
            AND semester = %s
            LIMIT 1
        """, (sub_id, exam_date, sem_clean))

        existing_exam = cursor.fetchone()

        if existing_exam:
            conn.commit()
            return jsonify({"message": "Exam already exists"}), 200

        # 3️⃣ Insert only if not exists
        cursor.execute("""
            INSERT INTO exams (subject_id, subject_name, exam_date, department, semester, status) 
            VALUES (%s, %s, %s, %s, %s, 'not_allocated')
        """, (sub_id, subj_name_clean, exam_date, dept_clean, sem_clean))
        
        conn.commit()
        return jsonify({"message": "Exam added successfully"}), 201

    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500
# --- CLASSROOM MANAGEMENT ---

@app.route("/admin/toggle-room/<int:id>", methods=["POST"])
def toggle_room(id):
    data = request.json
    cursor.execute("UPDATE classrooms SET is_active = %s WHERE id = %s", (data['is_active'], id))
    conn.commit()
    return jsonify({"message": "Status updated"}), 200

@app.route("/admin/delete-room/<int:room_id>", methods=["DELETE"])
def delete_room(room_id):
    try:
        # Check if the room is already being used in an allocation
        cursor.execute("SELECT id FROM allocations WHERE room_id = %s LIMIT 1", (room_id,))
        if cursor.fetchone():
            return jsonify({"error": "Cannot delete room. It has students allocated to it!"}), 400

        cursor.execute("DELETE FROM classrooms WHERE id = %s", (room_id,))
        conn.commit()
        return jsonify({"message": "Room deleted"}), 200
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500




@app.route("/staff/duty-details/<int:staff_id>", methods=["GET"])
def get_staff_duty(staff_id):
    # This finds the room assigned to the staff and the students in it
    cursor.execute("""
        SELECT r.room_number, st.name as staff_name, s.name as student_name, sa.seat_number, s.id
        FROM seating_arrangements sa
        JOIN classrooms r ON sa.room_id = r.id
        JOIN staff st ON sa.staff_id = st.id
        JOIN students s ON sa.student_id = s.id
        WHERE sa.staff_id = %s
    """, (staff_id,))
    rows = cursor.fetchall()
    
    if not rows: return jsonify({"error": "No duty assigned"}), 404
    
    students = [{"name": r[2], "seat": r[3], "student_id": r[4]} for r in rows]
    return jsonify({
        "room": rows[0][0],
        "staff_name": rows[0][1],
        "students": students
    }), 200




@app.route("/mark-attendance", methods=["POST"])
def mark_attendance():
    data = request.json
    student_id = data.get("student_id")
    staff_id = data.get("staff_id")

    # Get full snapshot EXACTLY like verify_face
    cursor.execute("""
        SELECT 
            u.name, 
            s.department, 
            sub.subject_name, 
            e.exam_date,
            c.room_name, 
            a.seat_number, 
            st.name, 
            st.department, 
            a.exam_id,
            ss.semester,
            sub.exam_center
        FROM users u
        JOIN students s ON u.id = s.user_id
        JOIN allocations a ON u.id = a.student_id
        JOIN exams e ON a.exam_id = e.id
        JOIN subjects sub ON e.subject_id = sub.id
        JOIN student_subjects ss 
            ON ss.subject_id = sub.id AND ss.student_id = s.id
        LEFT JOIN classrooms c ON a.room_id = c.id
        LEFT JOIN staff st ON a.staff_id = st.user_id
        WHERE u.id = %s AND a.staff_id = %s
        LIMIT 1
    """, (student_id, staff_id))

    snapshot = cursor.fetchone()

    if not snapshot:
        return jsonify({"message": "No allocation found"}), 404

    (
        s_name,
        s_dept,
        sub_name,
        e_date,
        r_name,
        s_no,
        st_name,
        st_dept,
        e_id,
        semester,
        exam_center
    ) = snapshot

    # Update allocation
    cursor.execute("""
        UPDATE allocations 
        SET status = 'PRESENT'
        WHERE student_id = %s AND exam_id = %s
    """, (student_id, e_id))

    # SAME UPSERT AS verify_face
    cursor.execute("""
        INSERT INTO attendance_history 
        (student_id, exam_id, student_name, register_number, student_dept, 
         room_name, seat_no, staff_name, staff_dept, subject_name, exam_date, 
         semester, exam_center, status)
        VALUES (%s, %s, %s, NULL, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'PRESENT')
        ON CONFLICT (student_id, exam_id) 
        DO UPDATE SET 
            student_name = EXCLUDED.student_name,
            student_dept = EXCLUDED.student_dept,
            room_name = EXCLUDED.room_name,
            seat_no = EXCLUDED.seat_no,
            staff_name = EXCLUDED.staff_name,
            staff_dept = EXCLUDED.staff_dept,
            subject_name = EXCLUDED.subject_name,
            exam_date = EXCLUDED.exam_date,
            semester = EXCLUDED.semester,
            exam_center = EXCLUDED.exam_center,
            status = 'PRESENT'
    """, (
        student_id,
        e_id,
        s_name,
        s_dept,
        r_name,
        s_no,
        st_name,
        st_dept,
        sub_name,
        e_date,
        semester,
        exam_center
    ))

    conn.commit()
    return jsonify({"message": "Marked Present Successfully ✅"}), 200


# NEW: Route to delete an allocation
@app.route("/admin/delete-allocation/<int:exam_id>", methods=["DELETE"])
def delete_allocation(exam_id):
    try:
        cursor.execute("DELETE FROM seating_arrangements WHERE exam_id = %s", (exam_id,))
        cursor.execute("UPDATE exams SET status = 'Pending' WHERE id = %s", (exam_id,))
        conn.commit()
        return jsonify({"message": "Allocation cleared"}), 200
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500


@app.route("/admin/exams", methods=["GET"])
def get_exams():
    try:
        query = """
            SELECT 
                e.id, 
                sub.subject_name, 
                sub.subject_code,
                sub.exam_date, 
                sub.department, 
                sub.semester,
                -- FIX: Check against the EXAM ID (e.id), not the subject id
                CASE 
                    WHEN (SELECT COUNT(*) FROM allocations WHERE exam_id = e.id) > 0 
                    THEN 'allocated' 
                    ELSE 'not allocated' 
                END as smart_status,
                (SELECT COUNT(DISTINCT ss.student_id) 
                 FROM student_subjects ss
                 WHERE UPPER(TRIM(ss.subject_code)) = UPPER(TRIM(sub.subject_code))
                   AND UPPER(TRIM(ss.department)) = UPPER(TRIM(sub.department))
                   AND ss.semester = sub.semester
                   AND ss.exam_date = sub.exam_date
                ) as student_count
            FROM exams e
            JOIN subjects sub ON e.subject_id = sub.id
            ORDER BY sub.exam_date ASC
        """
        cursor.execute(query)
        exams = cursor.fetchall()
        
        results = []
        for r in exams:
            results.append({
                "id": r[0], 
                "subject_name": r[1], 
                "subject_code": r[2],
                "date": str(r[3]), 
                "dept": r[4], 
                "sem": r[5],
                "status": r[6],
                "total_students": r[7]
            })
        return jsonify(results), 200
    except Exception as e:
        print(f"Fetch Error: {e}")
        return jsonify({"error": str(e)}), 500
@app.route("/admin/allocate/<subject_identifier>", methods=["POST"])
def allocate_exam(subject_identifier):
    try:
        target = str(subject_identifier).strip()

        # 1️⃣ Get the correct EXAM ID (NOT subject id)
        cursor.execute("""
            SELECT e.id, s.subject_code, s.subject_name,
                   e.exam_date, e.semester, s.exam_center
            FROM exams e
            JOIN subjects s ON e.subject_id = s.id
            WHERE UPPER(s.subject_name) = UPPER(%s) 
               OR UPPER(s.subject_code) = UPPER(%s)
            ORDER BY e.id DESC LIMIT 1
        """, (target, target))
        
        exam_data = cursor.fetchone()
        if not exam_data:
            return jsonify({"error": "Exam not found for this subject"}), 404
        
        real_exam_id, real_subj_code, subject_name, exam_date, semester, exam_center = exam_data

        # 2️⃣ Fetch correct USER IDs of students
        cursor.execute("""
            SELECT s.user_id 
            FROM student_subjects ss
            JOIN students s ON ss.student_id = s.id
            WHERE UPPER(TRIM(ss.subject_code)) = UPPER(TRIM(%s))
        """, (real_subj_code,))
        
        students = [r[0] for r in cursor.fetchall()]
        
        if not students:
            return jsonify({"error": "No students found in registration table"}), 400

        random.shuffle(students)

        # 3️⃣ Get Classrooms and Staff
        cursor.execute("""
            SELECT id, capacity, room_name
            FROM classrooms 
            WHERE is_active = TRUE 
            ORDER BY room_name ASC
        """)
        rooms = cursor.fetchall()
        
        cursor.execute("SELECT id FROM users WHERE role = 'staff'")
        all_staff_ids = [r[0] for r in cursor.fetchall()]

        # 4️⃣ HARD RESET old allocations for THIS EXAM
        cursor.execute("DELETE FROM allocations WHERE exam_id = %s", (real_exam_id,))
        cursor.execute("DELETE FROM attendance_history WHERE exam_id = %s", (real_exam_id,))

        # Identify staff already busy with OTHER exams
        cursor.execute("""
            SELECT DISTINCT staff_id 
            FROM allocations 
            WHERE exam_id != %s 
              AND staff_id IS NOT NULL
        """, (real_exam_id,))
        busy_staff = {r[0] for r in cursor.fetchall()}

        student_idx = 0
        total_students = len(students)

        for room_id, capacity, room_name in rooms:
            if student_idx >= total_students:
                break
            
            cursor.execute("""
                SELECT staff_id FROM allocations 
                WHERE room_id = %s AND staff_id IS NOT NULL 
                LIMIT 1
            """, (room_id,))
            existing_room_staff = cursor.fetchone()

            if existing_room_staff:
                room_staff = existing_room_staff[0]
            else:
                available_staff = [s for s in all_staff_ids if s not in busy_staff]
                
                if available_staff:
                    room_staff = random.choice(available_staff)
                    busy_staff.add(room_staff)
                elif all_staff_ids:
                    room_staff = random.choice(all_staff_ids)
                else:
                    room_staff = None

            for seat in range(1, capacity + 1):
                if student_idx >= total_students:
                    break
                
                seat_label = f"Seat {seat}"
                
                cursor.execute("""
                    SELECT COUNT(*) 
                    FROM allocations 
                    WHERE room_id = %s 
                      AND seat_number = %s
                """, (room_id, seat_label))
                
                if cursor.fetchone()[0] == 0:

                    current_student_id = students[student_idx]

                    # 🔹 Get student details
                    cursor.execute("""
                        SELECT u.name, s.register_number, s.department
                        FROM users u
                        JOIN students s ON u.id = s.user_id
                        WHERE u.id = %s
                    """, (current_student_id,))
                    student_info = cursor.fetchone()

                    if not student_info:
                        student_idx += 1
                        continue

                    student_name, register_number, student_dept = student_info

                    # 🔹 Get staff details
                    staff_name = None
                    staff_dept = None
                    if room_staff:
                        cursor.execute("""
                            SELECT u.name, st.department
                            FROM users u
                            JOIN staff st ON u.id = st.user_id
                            WHERE u.id = %s
                        """, (room_staff,))
                        staff_info = cursor.fetchone()
                        if staff_info:
                            staff_name, staff_dept = staff_info

                    # 🔹 INSERT INTO allocations
                    cursor.execute("""
                        INSERT INTO allocations 
                        (exam_id, student_id, room_id, staff_id, seat_number, status)
                        VALUES (%s, %s, %s, %s, %s, 'ABSENT')
                    """, (real_exam_id, current_student_id, room_id, room_staff, seat_label))

                    # 🔹 INSERT FULL DATA INTO attendance_history
                    cursor.execute("""
                        INSERT INTO attendance_history 
                        (exam_id, student_id, student_name, register_number,
                         student_dept, room_name, seat_no, staff_name,
                         staff_dept, subject_name, exam_date, status,
                         semester, exam_center)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                                'ABSENT', %s, %s)
                    """, (
                        real_exam_id,
                        current_student_id,
                        student_name,
                        register_number,
                        student_dept,
                        room_name,
                        seat_label,
                        staff_name,
                        staff_dept,
                        subject_name,
                        exam_date,
                        semester,
                        exam_center
                    ))

                    student_idx += 1

        # ✅ Update exam status
        cursor.execute("""
            UPDATE exams
            SET status = 'allocated'
            WHERE id = %s
        """, (real_exam_id,))

        conn.commit()
        return jsonify({"message": f"Allocated {student_idx} students successfully!"}), 200

    except Exception as e:
        conn.rollback()
        print(f"Error: {e}")
        return jsonify({"error": str(e)}), 500

 #---  Fetch allocation details  ---       
@app.route("/admin/allocation-details/<subject_identifier>", methods=["GET"])
def get_allocation_details(subject_identifier):
    try:
        target = str(subject_identifier).strip()

        cursor.execute("""
            SELECT e.id FROM exams e
            JOIN subjects s ON e.subject_id = s.id
            WHERE UPPER(s.subject_name) = UPPER(%s) OR UPPER(s.subject_code) = UPPER(%s)
            ORDER BY e.id DESC LIMIT 1
        """, (target, target))
        
        exam_data = cursor.fetchone()
        if not exam_data: 
            return jsonify([]), 200
            
        real_exam_id = exam_data[0]

        cursor.execute("""
            SELECT 
                a.seat_number, 
                u.name as student_name, 
                c.room_name, 
                COALESCE(s.department, 'N/A'), 
                COALESCE(stf.name, 'Not Assigned')
            FROM allocations a
            JOIN users u ON a.student_id = u.id
            LEFT JOIN students s ON u.id = s.user_id
            JOIN classrooms c ON a.room_id = c.id
            LEFT JOIN users stf ON a.staff_id = stf.id
            WHERE a.exam_id = %s
            ORDER BY c.room_name ASC, 
                     CAST(SUBSTRING(a.seat_number FROM '[0-9]+') AS INTEGER) ASC
        """, (real_exam_id,))

        result = [{
            "seat_number": r[0],
            "student_name": r[1],
            "room_name": r[2],
            "dept": r[3],
            "staff_name": r[4]
        } for r in cursor.fetchall()]
        
        return jsonify(result), 200
    except Exception as e:
        print(f"GET Error: {e}")
        return jsonify([]), 200

# NEW ROUTE: To allow manual editing of staff
@app.route("/admin/update-staff", methods=["POST"])
def update_staff():
    data = request.json
    try:
        # 1. Get the proper user_id based on the name
        # Using user_id instead of 'id' to stay consistent with your other queries
        cursor.execute("SELECT user_id FROM staff WHERE name = %s LIMIT 1", (data['staff_name'],))
        user_row = cursor.fetchone()
        
        if not user_row:
            return jsonify({"error": f"Staff member '{data['staff_name']}' not found"}), 404
        
        new_staff_id = user_row[0]
        
        # 2. Update the allocation
        # We use the allocation_id passed from Flutter to target the specific row
        cursor.execute("""
            UPDATE allocations 
            SET staff_id = %s 
            WHERE id = %s
        """, (new_staff_id, data['allocation_id']))
        
        conn.commit()
        print(f"✅ Success: Updated Allocation {data['allocation_id']} to Staff ID {new_staff_id} ({data['staff_name']})")
        
        return jsonify({"message": "Staff updated successfully"}), 200

    except Exception as e:
        print(f"🔥 UPDATE ERROR: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route("/admin/delete-exam/<int:exam_id>", methods=["DELETE"])
def delete_exam(exam_id):
    try:
        # 1. FIND the subject_id
        cursor.execute("SELECT subject_id FROM exams WHERE id = %s", (exam_id,))
        row = cursor.fetchone()
        
        if row:
            subj_id = row[0]
            
            # --- NEW STEP: PHOTOCOPY (ARCHIVE) ---
            # This saves the exam details, students, staff, and status FOREVER
            archive_exam_data(subj_id) 
            print(f"✅ Exam {subj_id} archived to history.")
            # -------------------------------------

            # 2. Clean up live allocations
            # FIX: We delete from allocations using the exam_id (not subj_id) 
            # to match how they were stored.
            cursor.execute("DELETE FROM allocations WHERE exam_id = %s", (exam_id,))

        # 3. Delete the actual exam record
        cursor.execute("DELETE FROM exams WHERE id = %s", (exam_id,))
        
        conn.commit()
        return jsonify({"message": "Exam archived to History and deleted from Live"}), 200
    except Exception as e:
        conn.rollback()
        print(f"❌ DELETE ERROR: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/student/register-exam", methods=["POST"])
def register_exam():
    data = request.json
    # This is what puts data into the 'empty' table
    cursor.execute("""
        INSERT INTO semester_details (student_id, subject_name, exam_date)
        VALUES (%s, %s, %s)
    """, (data['student_id'], data['subject'], data['date']))
    conn.commit()
    return jsonify({"message": "Registered!"})        




@app.route("/student/add-subject", methods=["POST"])
def add_student_subject():
    data = request.json
    try:
        # Check if subject exists, if not, you can create it or just link it
        cursor.execute("""
            INSERT INTO student_subjects (student_id, subject_id, semester)
            VALUES (%s, %s, %s)
        """, (data['student_id'], data['subject_id'], data['semester']))
        conn.commit()
        return jsonify({"message": "Subject added to your list"}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# 1. Route to add a new classroom
@app.route("/admin/add-classroom", methods=["POST"])
def add_classroom():
    data = request.json
    try:
        # We clean the room name just like we did for subjects
        room_name = data['room_number'].strip().upper() 
        capacity = int(data['capacity'])

        cursor.execute("""
            INSERT INTO classrooms (room_name, capacity, is_active)
            VALUES (%s, %s, TRUE)
            ON CONFLICT (room_name) DO UPDATE SET capacity = EXCLUDED.capacity
        """, (room_name, capacity))
        
        conn.commit()
        return jsonify({"message": f"Room {room_name} added successfully!"}), 201
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500

# 2. Route to get all classrooms (for your list below the form)
@app.route("/admin/classrooms", methods=["GET"])
def get_classrooms():
    try:
        cursor.execute("SELECT id, room_name, capacity, is_active FROM classrooms ORDER BY room_name")
        rooms = cursor.fetchall()
        results = [
            {"id": r[0], "room_number": r[1], "capacity": r[2], "is_active": r[3]} 
            for r in rooms
        ]
        return jsonify(results), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# 3. Route to toggle the room ON/OFF
@app.route("/admin/toggle-classroom/<int:room_id>", methods=["POST"])
def toggle_classroom(room_id):
    try:
        data = request.json
        cursor.execute("UPDATE classrooms SET is_active = %s WHERE id = %s", (data['is_active'], room_id))
        conn.commit()
        return jsonify({"message": "Status updated"}), 200
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500


@app.route("/admin/update-allocation", methods=["POST"])
def update_allocation():
    data = request.json
    try:
        # We target the specific allocation ID and update its room or seat
        cursor.execute("""
            UPDATE allocations 
            SET room_id = %s, seat_number = %s, staff_id = %s
            WHERE exam_id = %s AND student_id = %s
        """, (
            data['room_id'], 
            data['seat_number'], 
            data.get('staff_id'), # Staff can be optional
            data['exam_id'], 
            data['student_id']
        ))
        
        conn.commit()
        return jsonify({"message": "Allocation updated manually"}), 200
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500


@app.route("/admin/reassign-staff", methods=["POST"])
def reassign_staff():
    try:
        data = request.json
        allocation_id = data.get("allocation_id")   # or use (exam_id, seat_number)
        new_staff_id   = data.get("new_staff_id")

        if not allocation_id or not new_staff_id:
            return jsonify({"error": "Missing allocation_id or new_staff_id"}), 400

        cursor.execute("""
            UPDATE allocations
            SET staff_id = %s,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = %s
            RETURNING id
        """, (new_staff_id, allocation_id))
        
        if cursor.rowcount == 0:
            return jsonify({"error": "Allocation not found"}), 404
        
        conn.commit()
        return jsonify({"message": "Staff reassigned"}), 200

    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500



@app.route("/admin/update-room-staff", methods=["POST"])
def update_room_staff():
    try:
        data = request.json
        room_name = data.get('room_name', '').strip()
        new_staff_name = data.get('new_staff_name', '').strip()

        # 1. Get the Room ID from the classrooms table
        cursor.execute("SELECT id FROM classrooms WHERE room_name = %s", (room_name,))
        room_result = cursor.fetchone()
        if not room_result:
            return jsonify({"error": "Room not found"}), 404
        room_id = room_result[0]

        # 2. FIND THE USER ID
        cursor.execute("""
            SELECT u.id 
            FROM users u
            JOIN staff s ON u.id = s.user_id
            WHERE UPPER(s.name) = UPPER(%s)
            LIMIT 1
        """, (new_staff_name,))
        
        user_result = cursor.fetchone()
        
        if not user_result:
            return jsonify({"error": f"Could not find a user account for '{new_staff_name}'"}), 404
        
        correct_user_id = user_result[0]

        # 3. UPDATE ALLOCATIONS
        cursor.execute("""
            UPDATE allocations 
            SET staff_id = %s 
            WHERE room_id = %s
        """, (correct_user_id, room_id))

        # 🔹 NEW ADDITION: Update attendance_history snapshot also

        # Get staff name and department
        cursor.execute("""
            SELECT u.name, s.department
            FROM users u
            JOIN staff s ON u.id = s.user_id
            WHERE u.id = %s
        """, (correct_user_id,))
        staff_info = cursor.fetchone()

        if staff_info:
            new_staff_display_name, new_staff_dept = staff_info

            cursor.execute("""
                UPDATE attendance_history
                SET staff_name = %s,
                    staff_dept = %s
                WHERE room_name = %s
            """, (new_staff_display_name, new_staff_dept, room_name))

        affected_rows = cursor.rowcount
        conn.commit()

        print(f"--- GLOBAL UPDATE SUCCESS ---")
        print(f"Room: {room_name} (ID: {room_id})")
        print(f"Staff: {new_staff_name} (User ID: {correct_user_id})")
        print(f"Students Updated: {affected_rows}")

        return jsonify({
            "message": "Success", 
            "updated_count": affected_rows
        }), 200

    except Exception as e:
        if conn: conn.rollback()
        print(f"🔥 Backend Error: {str(e)}")
        return jsonify({"error": str(e)}), 500

#------------------------ADMIT CARD-----------------------------

@app.route("/get-admit-card/<int:user_id>", methods=["GET"])
def get_admit_card(user_id):
    try:
        cursor.execute("""
            SELECT id, name, register_number, photo_path, department 
            FROM students WHERE user_id = %s
        """, (user_id,))
        student = cursor.fetchone()
        if not student:
            return jsonify({"error": "Student record not found"}), 404

        student_id, name, reg_no, photo_path, dept = student
        
        file_name = os.path.basename(photo_path.replace('\\', '/')) if photo_path else None
        photo_url = f"{request.host_url}uploads/{file_name}" if file_name else None

        query = """
        (
            SELECT 
                e.exam_date, 
                sub.subject_name, 
                sub.subject_code, 
                sub.exam_center, 
                ss.semester,
                COALESCE(h.status, 'ABSENT') as db_status
            FROM student_subjects ss
            JOIN subjects sub ON ss.subject_id = sub.id
            JOIN exams e ON e.subject_id = sub.id
            LEFT JOIN attendance_history h 
                ON h.student_id = %s 
                AND h.exam_id = e.id
            WHERE ss.student_id = %s
        )

        UNION

        (
            SELECT 
                h.exam_date,
                h.subject_name,
                NULL as subject_code,
                h.exam_center,
                h.semester,
                h.status as db_status
            FROM attendance_history h
            WHERE h.student_id = %s
              AND NOT EXISTS (
                  SELECT 1 FROM exams e WHERE e.id = h.exam_id
              )
        )

        ORDER BY semester ASC, exam_date ASC
        """

        cursor.execute(query, (user_id, student_id, user_id))
        rows = cursor.fetchall()

        today = date.today()
        sem_map = {
            1: "FIRST", 2: "SECOND", 3: "THIRD", 4: "FOURTH",
            5: "FIFTH", 6: "SIXTH", 7: "SEVENTH", 8: "EIGHTH"
        }
        semesters_dict = {}

        for r in rows:
            sem_title = f"{sem_map.get(r[4], 'UG')} SEMESTER"
            if sem_title not in semesters_dict:
                semesters_dict[sem_title] = {
                    "title": sem_title,
                    "center": r[3] or "N/A",
                    "exams": []
                }
            
            raw_status = (r[5] or "").strip().upper()
            
            if raw_status == "PRESENT":
                final_status = "PRESENT"
            elif raw_status == "ABSENT":
                final_status = "ABSENT"
            elif r[0] > today:
                final_status = "N/A"
            else:
                final_status = "ABSENT"

            semesters_dict[sem_title]["exams"].append({
                "date": str(r[0]),
                "subject_name": r[1],
                "subject_code": r[2],
                "status": final_status
            })

        return jsonify({
            "university": "UNIVERSITY OF CALICUT", 
            "name": name, 
            "reg_no": reg_no, 
            "photo": photo_url, 
            "dept": dept, 
            "semesters": list(semesters_dict.values())
        }), 200

    except Exception as e:
        print(f"Error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/get-admit-card-by-reg/<string:reg_no>", methods=["GET"])
def get_admit_card_by_reg(reg_no):
    try:
        conn.rollback() # Reset transaction
        
        cursor.execute("SELECT user_id FROM students WHERE register_number = %s", (reg_no,))
        result = cursor.fetchone()
        
        if not result:
            return jsonify({"error": "Student not found"}), 404
        
        return get_admit_card(result[0])
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500
        

# 2. New route to manually override attendance (Present -> Absent)
@app.route("/update-attendance-manual", methods=["POST"])
def update_attendance_manual():
    try:
        data = request.json
        print(f"DEBUG FROM FLUTTER: {data}")

        alloc_id = data.get("allocation_id")
        reg_no = data.get("register_number")
        subject_name = data.get("subject_name")
        # ✅ Ensure status is UPPERCASE to match get_admit_card logic
        new_status = str(data.get("status", "ABSENT")).strip().upper()

        if alloc_id:
            where_clause = "a.id = %s"
            param = (alloc_id,)
        elif reg_no and subject_name:
            where_clause = "s.register_number = %s AND UPPER(TRIM(sub.subject_name)) = UPPER(TRIM(%s))"
            param = (reg_no, subject_name)
        else:
            print("❌ Error: Incomplete data from Flutter")
            return jsonify({"success": False, "message": "Incomplete data"}), 400

        query = f"""
            SELECT 
                a.id, a.student_id, u.name, s.department, 
                a.exam_id, sub.exam_date,
                c.room_name, a.seat_number, 
                st.name, st.department,
                sub.subject_name, s.register_number
            FROM allocations a
            JOIN users u ON a.student_id = u.id
            LEFT JOIN students s ON u.id = s.user_id
            JOIN exams e ON a.exam_id = e.id
            JOIN subjects sub ON e.subject_id = sub.id
            LEFT JOIN classrooms c ON a.room_id = c.id
            LEFT JOIN staff st ON a.staff_id = st.user_id
            WHERE {where_clause}
        """
        cursor.execute(query, param)
        row = cursor.fetchone()

        if not row:
            print(f"❌ Error: Could not find allocation for {param}")
            return jsonify({"success": False, "message": "Allocation not found"}), 404

        res_id, s_id, s_name, s_dept, e_id, e_date, r_name, s_no, st_name, st_dept, sub_name, actual_reg = row
        
        # 1. Update main allocations table
        cursor.execute("UPDATE allocations SET status = %s WHERE id = %s", (new_status, res_id))
        
        # 2. Sync to history (This is what the Admit Card reads)
        cursor.execute("""
            INSERT INTO attendance_history 
            (student_id, exam_id, student_name, register_number, student_dept, 
             room_name, seat_no, staff_name, staff_dept, subject_name, exam_date, status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (student_id, exam_id) 
            DO UPDATE SET status = EXCLUDED.status;
        """, (s_id, e_id, s_name, actual_reg, s_dept, r_name, s_no, st_name, st_dept, sub_name, e_date, new_status))

        conn.commit()
        return jsonify({"success": True, "message": f"Status updated to {new_status}"}), 200

    except Exception as e:
        if conn: conn.rollback()
        print(f"🔥 Update Error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

        
@app.route("/admin-master-view", methods=["GET"])
def admin_master_view():
    try:
        # We fetch EVERYTHING from history. 
        # Since we use COALESCE(status, 'ABSENT') in the archive, 
        # every student will show up here.
        query = """
            SELECT 
                student_name, register_number, student_dept,
                room_name, seat_no, status,
                staff_name, staff_dept, subject_name, exam_date,
                semester, exam_center
            FROM attendance_history
            ORDER BY exam_date DESC, subject_name ASC, student_name ASC
        """
        cursor.execute(query)
        rows = cursor.fetchall()
        
        result = []
        for r in rows:
            result.append({
                "name": r[0],
                "reg_no": r[1],
                "student_dept": r[2],
                "classroom": r[3],
                "seat_no": r[4],
                "status": r[5].upper() if r[5] else "ABSENT",
                "staff_name": r[6],
                "staff_dept": r[7],
                "exam_name": r[8],
                "exam_date": str(r[9]) if r[9] else "N/A",
                "semester": r[10],
                "exam_center": r[11]
            })
        return jsonify(result), 200
    except Exception as e:
        print(f"❌ Master View Error: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/sync-exam-absentees/<int:exam_id>", methods=["POST"])
def sync_exam_absentees(exam_id):
    try:
        # This calls the same function your 'delete' route uses, 
        # but it DOES NOT delete the exam.
        archive_exam_data(exam_id)
        conn.commit()
        return jsonify({"success": True, "message": "Absentees synced to Master Report"}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"success": False, "error": str(e)}), 500


def archive_exam_data(exam_id):
    # This query "takes a picture" of all current data
    # It pulls the TEXT names from classrooms and staff tables
    archive_query = """
        INSERT INTO attendance_history 
        (exam_id, student_id, student_name, register_number, student_dept, 
         room_name, seat_no, staff_name, staff_dept, subject_name, exam_date, status)
        SELECT 
            sub.id, s.id, s.name, s.register_number, s.department,
            COALESCE(c.room_name, 'N/A'), 
            COALESCE(a.seat_number, 'N/A'), 
            COALESCE(st.name, 'Not Assigned'), 
            COALESCE(st.department, 'N/A'), 
            sub.subject_name, sub.exam_date, 
            COALESCE(a.status, 'ABSENT') 
        FROM students s
        JOIN allocations a ON s.id = a.student_id
        JOIN subjects sub ON a.exam_id = sub.id
        LEFT JOIN classrooms c ON a.room_id = c.id
        LEFT JOIN staff st ON a.staff_id = st.user_id
        WHERE a.exam_id = %s
        ON CONFLICT (student_id, exam_id) DO UPDATE SET 
            status = EXCLUDED.status,
            room_name = EXCLUDED.room_name,
            seat_no = EXCLUDED.seat_no,
            staff_name = EXCLUDED.staff_name,
            staff_dept = EXCLUDED.staff_dept;
    """
    cursor.execute(archive_query, (exam_id,))
    conn.commit()


import os
from flask import Flask, request, jsonify, send_from_directory

# 1. Setup specialized folders
DASHBOARD_DIR = os.path.join('uploads', 'dashboard_pics')
if not os.path.exists(DASHBOARD_DIR):
    os.makedirs(DASHBOARD_DIR)

# 2. Route to handle the upload
@app.route("/upload-profile-pic/<int:user_id>", methods=["POST"])
def upload_profile_pic(user_id):
    try:
        if 'file' not in request.files:
            return jsonify({"error": "No file part"}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({"error": "No selected file"}), 400

        # Save to the dashboard sub-folder
        filename = f"user_{user_id}.jpg"
        filepath = os.path.join(DASHBOARD_DIR, filename)
        file.save(filepath)

        # Update ONLY the dashboard_pic column to avoid breaking face recognition
        # We store the path relative to the app root so the static route can find it
        db_path = f"uploads/dashboard_pics/{filename}"
        cursor.execute("UPDATE students SET dashboard_pic = %s WHERE user_id = %s", (db_path, user_id))
        conn.commit()

        return jsonify({"message": "Success", "path": db_path}), 200

    except Exception as e:
        conn.rollback()
        print(f"CRITICAL UPLOAD ERROR: {e}")
        return jsonify({"error": str(e)}), 500

# 3. Static route so Flutter can display the image
@app.route('/uploads/dashboard_pics/<filename>')
def serve_dashboard_pic(filename):
    return send_from_directory(DASHBOARD_DIR, filename)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)