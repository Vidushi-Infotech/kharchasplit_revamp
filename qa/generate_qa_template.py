"""
KharchaSplit — End-to-End QA Test Case Workbook generator.

Produces an enterprise-grade .xlsx that a QA tester can use to track manual
end-to-end testing on a real device (Android + iOS). Tailored to KharchaSplit's
actual modules (Auth, Dashboard, Groups, Expenses, Settlements, Activity,
Reports, Friends, Profile) but the structure is reusable for any mobile app.

Run:
    python3 qa/generate_qa_template.py

Output:
    qa/KharchaSplit_QA_TestCases.xlsx
"""

from __future__ import annotations

import os
from datetime import date

from openpyxl import Workbook
from openpyxl.styles import (
    Alignment,
    Border,
    Font,
    PatternFill,
    Side,
)
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.worksheet.table import Table, TableStyleInfo

# ---------------------------------------------------------------------------
# Styling constants
# ---------------------------------------------------------------------------

NAVY = "1F4E78"
DARK_BLUE = "2E75B6"
LIGHT_BLUE = "DDEBF7"
LIGHT_GREEN = "E2EFDA"
LIGHT_YELLOW = "FFF2CC"
LIGHT_RED = "FCE4D6"
LIGHT_GREY = "F2F2F2"
BORDER_GREY = "BFBFBF"

HEADER_FONT = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
SECTION_FONT = Font(name="Calibri", size=12, bold=True, color="FFFFFF")
TITLE_FONT = Font(name="Calibri", size=20, bold=True, color=NAVY)
SUBTITLE_FONT = Font(name="Calibri", size=12, bold=True, color=NAVY)
BODY_FONT = Font(name="Calibri", size=10, color="000000")
NOTE_FONT = Font(name="Calibri", size=10, italic=True, color="595959")

HEADER_FILL = PatternFill("solid", fgColor=NAVY)
SECTION_FILL = PatternFill("solid", fgColor=DARK_BLUE)
ZEBRA_FILL = PatternFill("solid", fgColor=LIGHT_GREY)
NOTE_FILL = PatternFill("solid", fgColor=LIGHT_YELLOW)

THIN = Side(border_style="thin", color=BORDER_GREY)
ALL_BORDERS = Border(top=THIN, bottom=THIN, left=THIN, right=THIN)

WRAP_TOP = Alignment(horizontal="left", vertical="top", wrap_text=True)
CENTER = Alignment(horizontal="center", vertical="center", wrap_text=True)
LEFT_CENTER = Alignment(horizontal="left", vertical="center", wrap_text=True)

# ---------------------------------------------------------------------------
# Test-case sheet schema (single source of truth)
# ---------------------------------------------------------------------------

TC_COLUMNS = [
    ("Test Case ID", 14),
    ("Module Name", 18),
    ("Feature Name", 22),
    ("Screen Name", 22),
    ("Test Scenario", 30),
    ("Test Case Description", 50),
    ("Preconditions", 35),
    ("Test Steps", 55),
    ("Test Data", 30),
    ("Expected Result", 45),
    ("Actual Result", 35),
    ("Priority", 11),
    ("Severity", 12),
    ("Platform", 12),
    ("Device Name", 18),
    ("OS Version", 14),
    ("Build Version", 14),
    ("Status", 13),
    ("Defect ID", 13),
    ("Bug Description", 35),
    ("Evidence Link", 30),
    ("Tester Name", 16),
    ("Testing Date", 14),
    ("Retest Status", 14),
    ("Remarks", 28),
]

PRIORITY_OPTIONS = "High,Medium,Low"
SEVERITY_OPTIONS = "Critical,Major,Minor,Cosmetic"
PLATFORM_OPTIONS = "Android,iOS,Both"
STATUS_OPTIONS = "Pass,Fail,Blocked,Not Tested,In Progress"
RETEST_OPTIONS = "Not Required,Pending,Passed,Failed"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def add_table_header(ws, row: int, columns: list[tuple[str, int]]) -> None:
    """Write a styled header row and set column widths."""
    for col_idx, (name, width) in enumerate(columns, start=1):
        cell = ws.cell(row=row, column=col_idx, value=name)
        cell.font = HEADER_FONT
        cell.fill = HEADER_FILL
        cell.alignment = CENTER
        cell.border = ALL_BORDERS
        ws.column_dimensions[get_column_letter(col_idx)].width = width
    ws.row_dimensions[row].height = 32


def style_body_row(ws, row: int, n_cols: int, zebra: bool = False) -> None:
    for col_idx in range(1, n_cols + 1):
        cell = ws.cell(row=row, column=col_idx)
        cell.font = BODY_FONT
        cell.alignment = WRAP_TOP
        cell.border = ALL_BORDERS
        if zebra:
            cell.fill = ZEBRA_FILL


def add_test_cases(ws, header_row: int, cases: list[dict]) -> None:
    """Write test case rows starting at header_row + 1."""
    for i, tc in enumerate(cases):
        row = header_row + 1 + i
        values = [
            tc.get("id", ""),
            tc.get("module", ""),
            tc.get("feature", ""),
            tc.get("screen", ""),
            tc.get("scenario", ""),
            tc.get("description", ""),
            tc.get("preconditions", ""),
            tc.get("steps", ""),
            tc.get("test_data", ""),
            tc.get("expected", ""),
            tc.get("actual", ""),
            tc.get("priority", "Medium"),
            tc.get("severity", "Major"),
            tc.get("platform", "Both"),
            tc.get("device", ""),
            tc.get("os", ""),
            tc.get("build", ""),
            tc.get("status", "Not Tested"),
            tc.get("defect_id", ""),
            tc.get("bug_desc", ""),
            tc.get("evidence", ""),
            tc.get("tester", ""),
            tc.get("date", ""),
            tc.get("retest", "Not Required"),
            tc.get("remarks", ""),
        ]
        for col_idx, val in enumerate(values, start=1):
            ws.cell(row=row, column=col_idx, value=val)
        style_body_row(ws, row, len(TC_COLUMNS), zebra=(i % 2 == 1))
        # Tall enough for wrapped Steps / Expected
        ws.row_dimensions[row].height = 95


def attach_validations(ws, header_row: int, last_row: int) -> None:
    """Drop down validations on Priority, Severity, Platform, Status, Retest."""
    if last_row < header_row + 1:
        return
    targets = {
        12: PRIORITY_OPTIONS,
        13: SEVERITY_OPTIONS,
        14: PLATFORM_OPTIONS,
        18: STATUS_OPTIONS,
        24: RETEST_OPTIONS,
    }
    for col_idx, formula in targets.items():
        dv = DataValidation(
            type="list",
            formula1=f'"{formula}"',
            allow_blank=True,
            showErrorMessage=True,
        )
        dv.error = "Please pick from the dropdown."
        dv.prompt = "Pick a value"
        col_letter = get_column_letter(col_idx)
        dv.add(f"{col_letter}{header_row + 1}:{col_letter}{last_row + 200}")
        ws.add_data_validation(dv)


def make_test_sheet(wb: Workbook, sheet_name: str, intro: str, cases: list[dict]):
    """Create a sheet with intro block + header + test cases + validations."""
    ws = wb.create_sheet(sheet_name)

    # Intro
    ws.cell(row=1, column=1, value=sheet_name.replace("_", " "))
    ws.cell(row=1, column=1).font = TITLE_FONT
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=10)

    ws.cell(row=2, column=1, value=intro)
    ws.cell(row=2, column=1).font = NOTE_FONT
    ws.cell(row=2, column=1).alignment = WRAP_TOP
    ws.cell(row=2, column=1).fill = NOTE_FILL
    ws.merge_cells(start_row=2, start_column=1, end_row=2, end_column=len(TC_COLUMNS))
    ws.row_dimensions[2].height = 45

    header_row = 4
    add_table_header(ws, header_row, TC_COLUMNS)
    add_test_cases(ws, header_row, cases)

    last_row = header_row + len(cases)
    attach_validations(ws, header_row, last_row)

    # Freeze: keep header + ID/Module columns visible
    ws.freeze_panes = f"E{header_row + 1}"
    ws.sheet_view.showGridLines = False
    return ws


# ---------------------------------------------------------------------------
# TEST CASES
#
# Convention for IDs: <PREFIX>_<NN>  e.g. TC_AUTH_01, TC_GRP_05
# Steps use numbered lines separated by \n for readability inside the cell.
# ---------------------------------------------------------------------------


def auth_cases() -> list[dict]:
    base = dict(module="Authentication", priority="High", severity="Critical")
    cases = [
        # --- Sign Up ---
        {**base, "id": "TC_AUTH_01", "feature": "Sign Up", "screen": "Register Screen",
         "scenario": "New user can register with valid 10-digit Indian mobile number",
         "description": "Verify a brand-new user can successfully register with valid name + phone, receive OTP and create account.",
         "preconditions": "App freshly installed; phone number is NOT already registered.",
         "steps": "1. Launch app\n2. From Login → tap Register\n3. Enter Name: 'Test User'\n4. Enter Phone: 9876543210\n5. Tap Continue / Send OTP",
         "test_data": "Name: Test User\nPhone: 9876543210",
         "expected": "OTP screen opens; SMS/WhatsApp OTP received within 60s; success toast 'OTP sent to your phone'.",
         "platform": "Both"},
        {**base, "id": "TC_AUTH_02", "feature": "Sign Up", "screen": "Register Screen",
         "scenario": "Reject empty / whitespace name",
         "description": "Inline validation blocks submission when Name field is blank.",
         "preconditions": "Register Screen open.",
         "steps": "1. Leave Name empty (or only spaces)\n2. Enter valid phone 9876543210\n3. Tap Continue",
         "test_data": "Name: ''\nPhone: 9876543210",
         "expected": "Continue button disabled OR inline error 'Please enter your name'. No network call fires.",
         "priority": "High", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_AUTH_03", "feature": "Sign Up", "screen": "Register Screen",
         "scenario": "Reject invalid phone number formats",
         "description": "Validate phone field rejects letters, special chars, < 10 digits, > 15 digits.",
         "preconditions": "Register Screen open.",
         "steps": "1. Try phone = '12345' (short)\n2. Try phone = 'abcd123456' (letters)\n3. Try phone = '99999999999999999' (>15 digits)\n4. Try phone = '+0-987-654' (leading 0 after +)",
         "test_data": "Various invalid phone values",
         "expected": "Each case shows inline error 'Enter a valid mobile number'. No backend call made.",
         "priority": "High", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_AUTH_04", "feature": "Sign Up", "screen": "Register Screen",
         "scenario": "Existing phone number cannot register again",
         "description": "Backend returns 409 conflict; UI shows friendly message.",
         "preconditions": "Phone 9876543210 is already registered.",
         "steps": "1. Enter Name: Anyone\n2. Enter Phone: 9876543210\n3. Tap Continue",
         "test_data": "Phone already exists",
         "expected": "Error banner / snackbar 'Phone already registered — please log in.' User stays on Register Screen.",
         "priority": "High", "severity": "Critical", "platform": "Both"},
        {**base, "id": "TC_AUTH_05", "feature": "Sign Up", "screen": "Register Screen",
         "scenario": "Email is optional but validated when entered",
         "description": "Empty email succeeds; malformed email blocks submission.",
         "preconditions": "Register Screen open.",
         "steps": "1. Enter valid name & phone\n2. Leave email blank → submit (should pass)\n3. Now enter email = 'abc@xyz' (no TLD) → submit",
         "test_data": "Email: ''  and  'abc@xyz'",
         "expected": "Blank email accepted; malformed email shows inline 'Enter a valid email'.",
         "priority": "Medium", "severity": "Minor", "platform": "Both"},

        # --- Login (Password-based, latest commit) ---
        {**base, "id": "TC_AUTH_06", "feature": "Login", "screen": "Login Screen",
         "scenario": "Successful login with correct phone + password",
         "description": "Registered user can log in and lands on Dashboard.",
         "preconditions": "User registered & password set.",
         "steps": "1. Open Login screen\n2. Enter Phone: 9876543210\n3. Enter Password: Valid@123\n4. Tap Login",
         "test_data": "Phone: 9876543210\nPassword: Valid@123",
         "expected": "Dashboard opens; user's name visible in top bar; access + refresh tokens saved in secure storage.",
         "platform": "Both"},
        {**base, "id": "TC_AUTH_07", "feature": "Login", "screen": "Login Screen",
         "scenario": "Wrong password shows error and increments attempt counter",
         "description": "Backend returns 401; UI keeps user on login screen with error.",
         "preconditions": "Valid registered phone.",
         "steps": "1. Enter Phone: 9876543210\n2. Enter Password: WrongPass\n3. Tap Login",
         "test_data": "Password: WrongPass",
         "expected": "Error 'Invalid phone or password' shown. No tokens saved. Form retains phone, clears password.",
         "platform": "Both"},
        {**base, "id": "TC_AUTH_08", "feature": "Login", "screen": "Login Screen",
         "scenario": "Rate limit after 5 wrong attempts in a minute",
         "description": "Backend rate limiter trips; UI shows cool-down message.",
         "preconditions": "User account exists.",
         "steps": "1. Submit wrong password 6 times in 60 seconds",
         "test_data": "6 rapid wrong attempts",
         "expected": "From 6th attempt, response 429 'Too many attempts, try again in X seconds'.",
         "priority": "Medium", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_AUTH_09", "feature": "Login", "screen": "Login Screen",
         "scenario": "Password field masks input and toggles visibility",
         "description": "Password field shows • characters; eye icon toggles to plain text.",
         "preconditions": "Login screen open.",
         "steps": "1. Type a password\n2. Tap eye icon\n3. Tap again",
         "test_data": "Any string",
         "expected": "Eye toggles between obscured and visible. State resets when leaving the screen.",
         "priority": "Medium", "severity": "Minor", "platform": "Both"},
        {**base, "id": "TC_AUTH_10", "feature": "Login", "screen": "Login Screen",
         "scenario": "Login button disabled until both fields valid",
         "description": "Prevents premature submission.",
         "preconditions": "Login screen open.",
         "steps": "1. Empty form → button disabled\n2. Phone only → still disabled\n3. Both filled with valid input → enabled",
         "test_data": "Various states",
         "expected": "Button disabled state matches input validity. Loading spinner shows during request.",
         "priority": "Low", "severity": "Minor", "platform": "Both"},

        # --- Forgot Password ---
        {**base, "id": "TC_AUTH_11", "feature": "Forgot Password", "screen": "Forgot Password Screen",
         "scenario": "Request password reset via OTP for registered phone",
         "description": "Backend sends OTP; UI moves to OTP screen.",
         "preconditions": "User exists with phone 9876543210.",
         "steps": "1. Login → 'Forgot Password?'\n2. Enter Phone: 9876543210\n3. Tap Send OTP",
         "test_data": "Phone: 9876543210",
         "expected": "OTP delivered via SMS/WhatsApp. App navigates to OTP screen.",
         "platform": "Both"},
        {**base, "id": "TC_AUTH_12", "feature": "Forgot Password", "screen": "Forgot Password Screen",
         "scenario": "Reset OTP for unregistered phone returns generic message (no enumeration)",
         "description": "Security: backend must NOT reveal whether phone exists.",
         "preconditions": "Phone 9000000000 is NOT registered.",
         "steps": "1. Enter Phone: 9000000000\n2. Tap Send OTP",
         "test_data": "Unregistered phone",
         "expected": "Same 'If your number is registered, OTP has been sent' message as success path; no 'user not found' leak.",
         "priority": "High", "severity": "Critical", "platform": "Both"},
        {**base, "id": "TC_AUTH_13", "feature": "Forgot Password", "screen": "Reset Password Screen",
         "scenario": "Successful password reset and immediate login",
         "description": "After OTP verify, user sets new password and is logged in.",
         "preconditions": "OTP verified.",
         "steps": "1. Enter new password: NewPass@123\n2. Confirm: NewPass@123\n3. Tap Reset & Login",
         "test_data": "NewPass@123",
         "expected": "Old refresh tokens invalidated server-side. User lands on Dashboard with fresh tokens.",
         "platform": "Both"},
        {**base, "id": "TC_AUTH_14", "feature": "Forgot Password", "screen": "Reset Password Screen",
         "scenario": "Confirm password mismatch blocks reset",
         "description": "Inline validation.",
         "preconditions": "Reset screen open.",
         "steps": "1. Password: NewPass@123\n2. Confirm: NewPass@1234\n3. Tap Reset",
         "test_data": "Mismatched passwords",
         "expected": "Inline error 'Passwords do not match'. Button stays disabled.",
         "priority": "High", "severity": "Major", "platform": "Both"},

        # --- OTP Verification ---
        {**base, "id": "TC_AUTH_15", "feature": "OTP Verification", "screen": "OTP Screen",
         "scenario": "Valid OTP completes verification",
         "description": "Correct 6-digit OTP within validity window.",
         "preconditions": "OTP just sent.",
         "steps": "1. Enter 6-digit OTP\n2. Auto-submit or tap Verify",
         "test_data": "Correct OTP",
         "expected": "Navigation proceeds (Dashboard for login, Set Password for register).",
         "platform": "Both"},
        {**base, "id": "TC_AUTH_16", "feature": "OTP Verification", "screen": "OTP Screen",
         "scenario": "Wrong OTP shows error and clears boxes",
         "description": "Backend returns 401; UI handles gracefully.",
         "preconditions": "OTP sent.",
         "steps": "1. Enter wrong OTP: 000000\n2. Tap Verify",
         "test_data": "OTP: 000000",
         "expected": "Error 'Invalid OTP'. OTP boxes clear, focus returns to first box.",
         "platform": "Both"},
        {**base, "id": "TC_AUTH_17", "feature": "OTP Verification", "screen": "OTP Screen",
         "scenario": "Expired OTP after 10 minutes",
         "description": "OTP rejected after expiry.",
         "preconditions": "OTP sent > 10 min ago.",
         "steps": "1. Wait 11 minutes\n2. Enter the previously-sent OTP\n3. Verify",
         "test_data": "Expired OTP",
         "expected": "Error 'OTP expired — request a new one'. Resend button enabled.",
         "priority": "High", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_AUTH_18", "feature": "OTP Verification", "screen": "OTP Screen",
         "scenario": "Resend OTP works after 30-second timer",
         "description": "Cooldown timer disables Resend; expires correctly.",
         "preconditions": "OTP screen open.",
         "steps": "1. Observe Resend disabled (00:30 → 00:00)\n2. After 00:00, tap Resend",
         "test_data": "n/a",
         "expected": "Resend button enables at 0. New OTP delivered. Timer restarts.",
         "priority": "Medium", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_AUTH_19", "feature": "OTP Verification", "screen": "OTP Screen",
         "scenario": "OTP autofill on Android works (SMS Retriever / User Consent)",
         "description": "Native OTP autofill prompt picks the latest SMS.",
         "preconditions": "OTP sent via SMS.",
         "steps": "1. Wait for native autofill prompt\n2. Approve",
         "test_data": "n/a",
         "expected": "OTP fields populate automatically; verify auto-fires.",
         "priority": "Medium", "severity": "Minor", "platform": "Android"},
        {**base, "id": "TC_AUTH_20", "feature": "OTP Verification", "screen": "OTP Screen",
         "scenario": "iOS SMS autofill suggests OTP via keyboard chip",
         "description": "iOS shows the code in keyboard accessory.",
         "preconditions": "OTP sent.",
         "steps": "1. Tap the autofill chip above the keyboard",
         "test_data": "n/a",
         "expected": "OTP fields populate.",
         "priority": "Medium", "severity": "Minor", "platform": "iOS"},

        # --- Social Login ---
        {**base, "id": "TC_AUTH_21", "feature": "Social Login", "screen": "Login Screen",
         "scenario": "Google Sign-In completes and creates/links account",
         "description": "OAuth flow lands on Dashboard.",
         "preconditions": "Device has a Google account; URL scheme configured.",
         "steps": "1. Tap 'Continue with Google'\n2. Pick an account in the system sheet\n3. Approve consent",
         "test_data": "Real Google account",
         "expected": "Auth completes; lands on Dashboard with profile name + photo.",
         "priority": "High", "severity": "Critical", "platform": "Both"},
        {**base, "id": "TC_AUTH_22", "feature": "Social Login", "screen": "Login Screen",
         "scenario": "User cancels Google sheet — no crash, stays on Login",
         "description": "Cancellation handled gracefully.",
         "preconditions": "Google sheet open.",
         "steps": "1. Tap 'Continue with Google'\n2. Dismiss the system sheet",
         "test_data": "n/a",
         "expected": "No error toast. User stays on Login screen. No partial token saved.",
         "priority": "Medium", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_AUTH_23", "feature": "Social Login", "screen": "Login Screen",
         "scenario": "Facebook Login completes",
         "description": "FB OAuth flow.",
         "preconditions": "FB app installed OR web flow available.",
         "steps": "1. Tap 'Continue with Facebook'\n2. Approve permissions",
         "test_data": "FB test account",
         "expected": "Auth completes; user lands on Dashboard.",
         "priority": "High", "severity": "Major", "platform": "Both"},

        # --- Session Management ---
        {**base, "id": "TC_AUTH_24", "feature": "Session Management", "screen": "Any screen",
         "scenario": "Access token auto-refreshes on 401",
         "description": "Dio interceptor catches 401 and calls /auth/refresh.",
         "preconditions": "User logged in with a soon-to-expire token.",
         "steps": "1. Stay on app till access token expires (~7d) OR manually shorten on backend\n2. Open any data screen",
         "test_data": "Expired access token, valid refresh token",
         "expected": "Original request retries silently after refresh. UI does not show error.",
         "platform": "Both"},
        {**base, "id": "TC_AUTH_25", "feature": "Session Management", "screen": "Any screen",
         "scenario": "Refresh token expired → user is forced to login",
         "description": "Refresh fails; tokens cleared; navigate to Login.",
         "preconditions": "Refresh token expired (>30 days).",
         "steps": "1. Open app after refresh expired",
         "test_data": "Expired refresh token",
         "expected": "App routes to Login. Secure storage cleared. No infinite loop.",
         "priority": "High", "severity": "Critical", "platform": "Both"},
        {**base, "id": "TC_AUTH_26", "feature": "Session Management", "screen": "Splash Screen",
         "scenario": "Persisted session survives app restart",
         "description": "After kill + relaunch, user lands back on Dashboard.",
         "preconditions": "User previously logged in.",
         "steps": "1. Force-stop the app\n2. Relaunch",
         "test_data": "n/a",
         "expected": "Splash → Dashboard (no Login). Profile data loads.",
         "platform": "Both"},

        # --- Logout ---
        {**base, "id": "TC_AUTH_27", "feature": "Logout", "screen": "Profile Screen",
         "scenario": "Logout clears tokens and returns to Login",
         "description": "End-to-end logout path.",
         "preconditions": "User logged in.",
         "steps": "1. Profile → Logout\n2. Confirm in dialog",
         "test_data": "n/a",
         "expected": "Tokens removed from secure storage; cache cleared; lands on Login. Back button cannot return to Dashboard.",
         "platform": "Both"},
        {**base, "id": "TC_AUTH_28", "feature": "Logout", "screen": "Profile Screen",
         "scenario": "Logout cancel keeps user logged in",
         "description": "Confirmation dialog negative path.",
         "preconditions": "User logged in.",
         "steps": "1. Profile → Logout\n2. Cancel the dialog",
         "test_data": "n/a",
         "expected": "Dialog dismisses, user stays on Profile, fully logged in.",
         "priority": "Medium", "severity": "Minor", "platform": "Both"},
    ]
    return cases


def profile_cases() -> list[dict]:
    base = dict(module="User Profile", priority="High", severity="Major")
    return [
        {**base, "id": "TC_PROF_01", "feature": "View Profile", "screen": "Profile Screen",
         "scenario": "Profile shows current name, phone, email, avatar",
         "description": "Profile screen reads from /users/me.",
         "preconditions": "Logged in.",
         "steps": "1. Navigate to Profile tab",
         "test_data": "n/a",
         "expected": "Name, phone, email, avatar all match registered values.",
         "platform": "Both"},
        {**base, "id": "TC_PROF_02", "feature": "Edit Profile", "screen": "Edit Profile",
         "scenario": "Update name, save, see change instantly",
         "description": "Optimistic UI then server sync.",
         "preconditions": "Logged in.",
         "steps": "1. Tap Edit\n2. Change Name\n3. Save",
         "test_data": "Name: 'Test User Edited'",
         "expected": "Snackbar 'Profile updated'. Name visible across app (Dashboard, Activity).",
         "platform": "Both"},
        {**base, "id": "TC_PROF_03", "feature": "Edit Profile", "screen": "Edit Profile",
         "scenario": "Upload profile picture from gallery",
         "description": "Image picker → compress → base64 → PUT /users/me.",
         "preconditions": "Photos permission allowed.",
         "steps": "1. Tap avatar\n2. Pick a photo from gallery\n3. Crop & save",
         "test_data": "JPEG 3MB photo",
         "expected": "Compressed image displayed; <2MB on request body. Server responds 200.",
         "platform": "Both"},
        {**base, "id": "TC_PROF_04", "feature": "Edit Profile", "screen": "Edit Profile",
         "scenario": "Upload profile picture from camera",
         "description": "Camera capture path.",
         "preconditions": "Camera permission allowed.",
         "steps": "1. Tap avatar\n2. Choose Camera\n3. Take photo\n4. Save",
         "test_data": "n/a",
         "expected": "Photo captured and uploaded successfully.",
         "platform": "Both"},
        {**base, "id": "TC_PROF_05", "feature": "Edit Profile", "screen": "Edit Profile",
         "scenario": "Reject email format with no @ or TLD",
         "description": "Client-side email validation.",
         "preconditions": "Edit screen open.",
         "steps": "1. Email = 'badformat'\n2. Save",
         "test_data": "Email: 'badformat'",
         "expected": "Inline error; save disabled.",
         "priority": "Medium", "severity": "Minor", "platform": "Both"},
        {**base, "id": "TC_PROF_06", "feature": "Change Password", "screen": "Change Password",
         "scenario": "Update password with correct current password",
         "description": "Re-auth before mutation.",
         "preconditions": "User knows current password.",
         "steps": "1. Profile → Change Password\n2. Current, New, Confirm\n3. Save",
         "test_data": "Current: Valid@123\nNew: NewValid@123",
         "expected": "Success message. User remains logged in. Other devices' refresh tokens invalidated.",
         "priority": "High", "severity": "Critical", "platform": "Both"},
        {**base, "id": "TC_PROF_07", "feature": "Currency Preference", "screen": "Settings",
         "scenario": "Default currency selection persists across app",
         "description": "Preferred currency from user settings.",
         "preconditions": "Logged in.",
         "steps": "1. Set preferred currency = USD\n2. Reopen Add Expense",
         "test_data": "USD",
         "expected": "Add Expense defaults to USD; backend stores preference.",
         "priority": "Medium", "severity": "Minor", "platform": "Both"},
        {**base, "id": "TC_PROF_08", "feature": "Hide Sensitive Data", "screen": "Profile / Dashboard",
         "scenario": "Balances hidden when app backgrounded",
         "description": "Finance app security: balances should blur in app switcher.",
         "preconditions": "Logged in with non-zero balances.",
         "steps": "1. Open Dashboard\n2. Send app to background (swipe)\n3. Open app switcher",
         "test_data": "n/a",
         "expected": "Snapshot shows blurred / masked balances, not real numbers.",
         "priority": "High", "severity": "Major", "platform": "Both"},
    ]


def dashboard_cases() -> list[dict]:
    base = dict(module="Dashboard", priority="High", severity="Major")
    return [
        {**base, "id": "TC_DASH_01", "feature": "Balances", "screen": "Dashboard",
         "scenario": "Show 'You are owed' and 'You owe' aggregates",
         "description": "Aggregate balance pulled from /dashboard.",
         "preconditions": "Logged in with at least one outstanding balance.",
         "steps": "1. Open Dashboard",
         "test_data": "n/a",
         "expected": "Two cards: 'Owed to me' (green) and 'I owe' (red). Numbers match group breakdowns.",
         "platform": "Both"},
        {**base, "id": "TC_DASH_02", "feature": "Balances", "screen": "Dashboard",
         "scenario": "Tap 'Owed to me' shows itemized breakdown",
         "description": "Navigates to /home/owed-to-me with list per user.",
         "preconditions": "Aggregate > 0.",
         "steps": "1. Tap 'Owed to me' card",
         "test_data": "n/a",
         "expected": "Screen lists every user with amount and group context.",
         "platform": "Both"},
        {**base, "id": "TC_DASH_03", "feature": "Recent Activity", "screen": "Dashboard",
         "scenario": "Last 5 activity items rendered",
         "description": "Latest activity feed in compact form.",
         "preconditions": "Activity events exist.",
         "steps": "1. Scroll dashboard",
         "test_data": "n/a",
         "expected": "Up to 5 recent events with relative time ('2h ago'). Tapping item routes correctly.",
         "platform": "Both"},
        {**base, "id": "TC_DASH_04", "feature": "Pull-to-refresh", "screen": "Dashboard",
         "scenario": "Refresh fetches latest balances",
         "description": "RefreshIndicator on top.",
         "preconditions": "Logged in.",
         "steps": "1. Pull down at the top",
         "test_data": "n/a",
         "expected": "Spinner shows; data updates; spinner dismisses within 5s.",
         "platform": "Both"},
        {**base, "id": "TC_DASH_05", "feature": "Empty State", "screen": "Dashboard",
         "scenario": "Brand new account shows friendly empty state",
         "description": "No groups, no expenses.",
         "preconditions": "Fresh user.",
         "steps": "1. Register + log in\n2. View Dashboard",
         "test_data": "n/a",
         "expected": "Empty illustration + CTA 'Create a group' visible.",
         "platform": "Both"},
        {**base, "id": "TC_DASH_06", "feature": "Loading State", "screen": "Dashboard",
         "scenario": "Shimmer placeholders show during fetch",
         "description": "Three-state UI rule from CLAUDE.md.",
         "preconditions": "Slow network OR fresh open.",
         "steps": "1. Throttle network to Slow 3G\n2. Open Dashboard",
         "test_data": "n/a",
         "expected": "Shimmer cards animate until data arrives; no white flash.",
         "priority": "Medium", "severity": "Minor", "platform": "Both"},
        {**base, "id": "TC_DASH_07", "feature": "Error State", "screen": "Dashboard",
         "scenario": "Backend 500 shows error widget with retry",
         "description": "Three-state UI rule.",
         "preconditions": "Backend returns 500 (simulate).",
         "steps": "1. Open Dashboard",
         "test_data": "n/a",
         "expected": "Error card with 'Try again' button; tapping retries the fetch.",
         "priority": "High", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_DASH_08", "feature": "Responsive Layout", "screen": "Dashboard",
         "scenario": "Compact / Standard / Large layouts render correctly",
         "description": "<600 / 600-1100 / >1100 widths.",
         "preconditions": "Test on phone, tablet, and unfolded foldable / web.",
         "steps": "1. Open on phone\n2. Open on tablet\n3. Rotate / resize",
         "test_data": "n/a",
         "expected": "Compact: bottom nav. Standard: sidebar centered. Large: sidebar + max-width content. No overflow.",
         "priority": "High", "severity": "Major", "platform": "Both"},
    ]


def navigation_cases() -> list[dict]:
    base = dict(module="Navigation", priority="High", severity="Major")
    return [
        {**base, "id": "TC_NAV_01", "feature": "Bottom Nav", "screen": "Shell",
         "scenario": "All bottom nav tabs reachable on phone (<600)",
         "description": "Dashboard, Groups, Friends, Activity present.",
         "preconditions": "Logged in.",
         "steps": "1. Tap each bottom-nav icon",
         "test_data": "n/a",
         "expected": "Each tab opens the correct screen and highlights the selected icon.",
         "platform": "Both"},
        {**base, "id": "TC_NAV_02", "feature": "Sidebar Nav", "screen": "Shell",
         "scenario": "Tablet / web shows sidebar instead of bottom nav",
         "description": "Layouts switch at 600px.",
         "preconditions": "Tablet OR resized desktop window.",
         "steps": "1. Open app at ≥600px width",
         "test_data": "n/a",
         "expected": "Sidebar visible; bottom nav hidden; selecting items routes correctly.",
         "priority": "High", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_NAV_03", "feature": "Hardware Back", "screen": "Various",
         "scenario": "Android back button respects nested stack",
         "description": "Back from Expense Detail returns to Group Detail, not Dashboard.",
         "preconditions": "Inside a group expense.",
         "steps": "1. Dashboard → Groups → Group X → Expense Y\n2. Tap hardware Back",
         "test_data": "n/a",
         "expected": "Returns to Group X. Another back returns to Groups list. Another to Dashboard.",
         "priority": "High", "severity": "Major", "platform": "Android"},
        {**base, "id": "TC_NAV_04", "feature": "Hardware Back", "screen": "Dashboard",
         "scenario": "Back on root tab confirms before exiting app",
         "description": "Prevents accidental exit.",
         "preconditions": "On Dashboard.",
         "steps": "1. Tap hardware Back",
         "test_data": "n/a",
         "expected": "Toast/dialog 'Press back again to exit'. Second back within 2s exits.",
         "priority": "Medium", "severity": "Minor", "platform": "Android"},
        {**base, "id": "TC_NAV_05", "feature": "iOS Swipe Back", "screen": "Various",
         "scenario": "Swipe from left edge pops route",
         "description": "iOS standard gesture.",
         "preconditions": "iOS device, inside detail screen.",
         "steps": "1. Swipe right from left edge",
         "test_data": "n/a",
         "expected": "Previous screen reappears.",
         "priority": "Medium", "severity": "Minor", "platform": "iOS"},
        {**base, "id": "TC_NAV_06", "feature": "Deep Routes", "screen": "Various",
         "scenario": "Direct URL '/home/groups/:id' deep links to group detail",
         "description": "go_router supports deep links.",
         "preconditions": "Logged in.",
         "steps": "1. Trigger an FCM notification with route='/home/groups/<id>'",
         "test_data": "Valid group id",
         "expected": "App opens straight to that group detail.",
         "priority": "High", "severity": "Major", "platform": "Both"},
    ]


def groups_cases() -> list[dict]:
    base = dict(module="Groups", priority="High", severity="Major")
    return [
        {**base, "id": "TC_GRP_01", "feature": "Create Group", "screen": "Create Group",
         "scenario": "Create a group with required fields",
         "description": "Group creation with name + currency.",
         "preconditions": "Logged in.",
         "steps": "1. Groups → +\n2. Name: 'Goa Trip'\n3. Currency: INR\n4. Add 2 members from contacts\n5. Create",
         "test_data": "Name: Goa Trip\nCurrency: INR",
         "expected": "Group appears in Groups list. Creator listed as admin. Members visible.",
         "platform": "Both"},
        {**base, "id": "TC_GRP_02", "feature": "Create Group", "screen": "Create Group",
         "scenario": "Reject empty group name",
         "description": "Validation.",
         "preconditions": "Create screen open.",
         "steps": "1. Leave name blank\n2. Tap Create",
         "test_data": "Name: ''",
         "expected": "Inline error; Create disabled.",
         "priority": "High", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_GRP_03", "feature": "Create Group", "screen": "Create Group",
         "scenario": "Long name truncated nicely in lists",
         "description": "UI handles long strings.",
         "preconditions": "Create screen open.",
         "steps": "1. Name = 200 chars\n2. Create\n3. View in Groups list",
         "test_data": "200-char name",
         "expected": "Backend caps at allowed length OR UI truncates with ellipsis.",
         "priority": "Low", "severity": "Cosmetic", "platform": "Both"},
        {**base, "id": "TC_GRP_04", "feature": "Add Members", "screen": "Create Group",
         "scenario": "Add member from contacts who is already a KharchaSplit user",
         "description": "Registered users join immediately.",
         "preconditions": "Contact's phone is a registered user.",
         "steps": "1. Add Members → Contacts\n2. Select Atharv (registered)\n3. Confirm",
         "test_data": "Registered contact",
         "expected": "Member appears in group immediately. No pending invite.",
         "platform": "Both"},
        {**base, "id": "TC_GRP_05", "feature": "Add Members", "screen": "Create Group",
         "scenario": "Invite unregistered contact via WhatsApp (WATI)",
         "description": "Pending invite created; user joins when they register.",
         "preconditions": "Contact's phone NOT registered.",
         "steps": "1. Add Members → Contacts\n2. Select unregistered contact\n3. Confirm",
         "test_data": "Unregistered phone",
         "expected": "Pending invite row in group; WhatsApp message delivered via WATI; status updates to 'sent'.",
         "priority": "High", "severity": "Critical", "platform": "Both"},
        {**base, "id": "TC_GRP_06", "feature": "Group Detail", "screen": "Group Detail",
         "scenario": "View members, expenses, balances tabs",
         "description": "Three tabs/sections.",
         "preconditions": "Group exists.",
         "steps": "1. Open the group",
         "test_data": "n/a",
         "expected": "Members list, recent expenses, and per-member balances all populate.",
         "platform": "Both"},
        {**base, "id": "TC_GRP_07", "feature": "Edit Group", "screen": "Edit Group",
         "scenario": "Admin can rename group and change cover image",
         "description": "Editable group metadata.",
         "preconditions": "User is admin.",
         "steps": "1. Group Detail → ⋮ → Edit\n2. Change name and pick a cover image\n3. Save",
         "test_data": "New name + image",
         "expected": "Changes persist; visible to all members on refresh.",
         "platform": "Both"},
        {**base, "id": "TC_GRP_08", "feature": "Edit Group", "screen": "Edit Group",
         "scenario": "Non-admin cannot see/use Edit option",
         "description": "Permission gate.",
         "preconditions": "Member (not admin).",
         "steps": "1. Open group as non-admin\n2. Try ⋮ menu",
         "test_data": "n/a",
         "expected": "Edit option hidden / disabled. Direct API call (if attempted) returns 403.",
         "priority": "High", "severity": "Critical", "platform": "Both"},
        {**base, "id": "TC_GRP_09", "feature": "Archive Group", "screen": "Group Detail",
         "scenario": "Admin archives an active group",
         "description": "Group moved to archived section.",
         "preconditions": "Admin role; group active.",
         "steps": "1. Open group → ⋮ → Archive\n2. Confirm",
         "test_data": "n/a",
         "expected": "Group disappears from active list; visible in 'Archived' filter. is_archived flag set server-side.",
         "platform": "Both"},
        {**base, "id": "TC_GRP_10", "feature": "Unarchive Group", "screen": "Archived Groups",
         "scenario": "Unarchive restores to active list",
         "description": "Reverse of archive.",
         "preconditions": "Archived group present.",
         "steps": "1. Filter archived → open group → ⋮ → Unarchive",
         "test_data": "n/a",
         "expected": "Group returns to active list.",
         "priority": "Medium", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_GRP_11", "feature": "Delete Group", "screen": "Group Detail",
         "scenario": "Admin deletes empty group with confirmation",
         "description": "Soft delete; cannot be undone in UI.",
         "preconditions": "Admin; group with no expenses.",
         "steps": "1. ⋮ → Delete\n2. Confirm",
         "test_data": "n/a",
         "expected": "Group removed from list. Server soft-deletes (deleted_at set).",
         "priority": "High", "severity": "Critical", "platform": "Both"},
        {**base, "id": "TC_GRP_12", "feature": "Delete Group", "screen": "Group Detail",
         "scenario": "Cannot delete group with outstanding balances",
         "description": "Business rule.",
         "preconditions": "Group with unsettled balance.",
         "steps": "1. ⋮ → Delete",
         "test_data": "n/a",
         "expected": "Blocked with message 'Settle all balances before deleting'.",
         "priority": "High", "severity": "Critical", "platform": "Both"},
        {**base, "id": "TC_GRP_13", "feature": "Remove Member", "screen": "Members tab",
         "scenario": "Admin removes a member with zero balance",
         "description": "Soft-delete membership row.",
         "preconditions": "Member has zero balance in group.",
         "steps": "1. Members → Swipe / tap member → Remove\n2. Confirm",
         "test_data": "n/a",
         "expected": "Member disappears from list. Their past expenses preserved.",
         "platform": "Both"},
        {**base, "id": "TC_GRP_14", "feature": "Remove Member", "screen": "Members tab",
         "scenario": "Cannot remove member with outstanding balance",
         "description": "Business rule.",
         "preconditions": "Member owes/owed.",
         "steps": "1. Try to remove",
         "test_data": "n/a",
         "expected": "Blocked with 'Settle balances before removing.'",
         "priority": "High", "severity": "Critical", "platform": "Both"},
        {**base, "id": "TC_GRP_15", "feature": "Re-add Member", "screen": "Members tab",
         "scenario": "Previously removed member can be re-added (reactivation)",
         "description": "Backend reactivates soft-deleted row.",
         "preconditions": "Member previously removed.",
         "steps": "1. Add Member → pick same contact\n2. Confirm",
         "test_data": "Same user",
         "expected": "Re-added with same user_id, fresh joined_at. Activity log shows re-add.",
         "priority": "Medium", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_GRP_16", "feature": "Member Roles", "screen": "Members tab",
         "scenario": "Admin promotes a member to admin",
         "description": "Role change reflected immediately.",
         "preconditions": "Creator/admin role.",
         "steps": "1. Tap member → 'Make admin'\n2. Confirm",
         "test_data": "n/a",
         "expected": "Member badge updates to Admin. Cache invalidated.",
         "platform": "Both"},
    ]


def expenses_cases() -> list[dict]:
    base = dict(module="Expenses", priority="High", severity="Critical")
    return [
        {**base, "id": "TC_EXP_01", "feature": "Add Expense", "screen": "Add Expense",
         "scenario": "Equal split among all group members",
         "description": "Most common path.",
         "preconditions": "Group with 4 members; user is a member.",
         "steps": "1. + → Add Expense\n2. Title: 'Dinner'\n3. Amount: 1000\n4. Paid by: me\n5. Split: Equal\n6. Save",
         "test_data": "Amount 1000; 4 members",
         "expected": "Expense saved. Each split = 250. Dashboard and group balances reflect immediately.",
         "platform": "Both"},
        {**base, "id": "TC_EXP_02", "feature": "Add Expense", "screen": "Add Expense",
         "scenario": "Exact (unequal) split — amounts sum to total",
         "description": "Validates strict-equality rule.",
         "preconditions": "Group selected; Exact split chosen.",
         "steps": "1. Amount: 1000\n2. Set per-member amounts: 300, 300, 200, 200\n3. Save",
         "test_data": "Sum matches",
         "expected": "Save allowed. Validation passes.",
         "platform": "Both"},
        {**base, "id": "TC_EXP_03", "feature": "Add Expense", "screen": "Add Expense",
         "scenario": "Exact split rejects mismatched sum",
         "description": "Validator.",
         "preconditions": "Exact split.",
         "steps": "1. Amount: 1000\n2. Splits sum = 950\n3. Try Save",
         "test_data": "Sum off by 50",
         "expected": "Inline banner 'Splits must total 1000'; Save disabled.",
         "platform": "Both"},
        {**base, "id": "TC_EXP_04", "feature": "Add Expense", "screen": "Add Expense",
         "scenario": "Percentage split — must total 100%",
         "description": "Same rule for percentages.",
         "preconditions": "Percentage split.",
         "steps": "1. Set 50/30/15/5\n2. Save (=100%)",
         "test_data": "Sum = 100%",
         "expected": "Save allowed; per-user amounts computed; rounding handled within 0.01.",
         "platform": "Both"},
        {**base, "id": "TC_EXP_05", "feature": "Add Expense", "screen": "Add Expense",
         "scenario": "Shares split — at least one share > 0",
         "description": "Members with 0 shares excluded.",
         "preconditions": "Shares split.",
         "steps": "1. Member A:2, B:1, C:0, D:1\n2. Save",
         "test_data": "Mixed shares",
         "expected": "C excluded from split. Others split by 2:1:1.",
         "priority": "Medium", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_EXP_06", "feature": "Add Expense", "screen": "Add Expense",
         "scenario": "Amount must be > 0",
         "description": "Validation.",
         "preconditions": "Add Expense open.",
         "steps": "1. Amount: 0 OR -10\n2. Try Save",
         "test_data": "0, -10",
         "expected": "Error 'Amount must be greater than 0'.",
         "platform": "Both"},
        {**base, "id": "TC_EXP_07", "feature": "Add Expense", "screen": "Add Expense",
         "scenario": "Very large amount (₹1 crore) handled",
         "description": "Boundary.",
         "preconditions": "Add Expense open.",
         "steps": "1. Amount: 10000000\n2. Save",
         "test_data": "10000000",
         "expected": "Stored as DECIMAL(15,2); UI shows correctly formatted '₹1,00,00,000.00'.",
         "priority": "Medium", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_EXP_08", "feature": "Add Expense", "screen": "Add Expense",
         "scenario": "Decimal precision preserved (.01 paise)",
         "description": "No floating point drift.",
         "preconditions": "Add Expense.",
         "steps": "1. Amount: 100.07\n2. Equal split among 3 → 33.36 / 33.36 / 33.35\n3. Save",
         "test_data": "100.07",
         "expected": "Sum equals 100.07. No 100.06 / 100.08 drift.",
         "platform": "Both"},
        {**base, "id": "TC_EXP_09", "feature": "Add Expense", "screen": "Add Expense",
         "scenario": "Attach receipt from gallery",
         "description": "Compress + base64.",
         "preconditions": "Photos permission allowed.",
         "steps": "1. Add Expense → 📎 → Gallery\n2. Pick photo\n3. Save",
         "test_data": "5MB JPEG",
         "expected": "Image compresses to ≤2MB; expense saves; receipt thumbnail visible in detail.",
         "platform": "Both"},
        {**base, "id": "TC_EXP_10", "feature": "Add Expense", "screen": "Add Expense",
         "scenario": "Attach receipt via camera",
         "description": "Camera capture path.",
         "preconditions": "Camera permission allowed.",
         "steps": "1. + → Camera → capture\n2. Save expense",
         "test_data": "n/a",
         "expected": "Captured image attached. Server accepts.",
         "platform": "Both"},
        {**base, "id": "TC_EXP_11", "feature": "Add Expense", "screen": "Add Expense",
         "scenario": "Currency selector defaults to group currency",
         "description": "Group currency takes precedence over user preference inside that group.",
         "preconditions": "Group currency = USD.",
         "steps": "1. Add expense in group",
         "test_data": "n/a",
         "expected": "Currency preset = USD. POST body has currency='USD' (code, not symbol).",
         "priority": "Medium", "severity": "Minor", "platform": "Both"},
        {**base, "id": "TC_EXP_12", "feature": "Add Expense", "screen": "Add Expense",
         "scenario": "Date picker — pick past date",
         "description": "Expense date independent of created_at.",
         "preconditions": "Add Expense open.",
         "steps": "1. Tap date → pick yesterday\n2. Save",
         "test_data": "Yesterday",
         "expected": "Saved with expense_date=yesterday; created_at=now.",
         "platform": "Both"},
        {**base, "id": "TC_EXP_13", "feature": "Add Expense", "screen": "Add Expense",
         "scenario": "Date picker rejects future date if disallowed",
         "description": "Business rule — depends on product.",
         "preconditions": "Add Expense open.",
         "steps": "1. Pick a date 30 days in future",
         "test_data": "Future date",
         "expected": "Either allowed (with confirmation) OR blocked — must match spec.",
         "priority": "Low", "severity": "Minor", "platform": "Both"},
        {**base, "id": "TC_EXP_14", "feature": "Edit Expense", "screen": "Expense Detail",
         "scenario": "Payer can edit their expense",
         "description": "Permission check.",
         "preconditions": "Logged in as payer.",
         "steps": "1. Expense Detail → ✏\n2. Change amount or notes\n3. Save",
         "test_data": "n/a",
         "expected": "Updated values persisted. Cache invalidated. Balances recompute.",
         "platform": "Both"},
        {**base, "id": "TC_EXP_15", "feature": "Edit Expense", "screen": "Expense Detail",
         "scenario": "Non-payer cannot edit",
         "description": "Permission gate.",
         "preconditions": "Logged in as a different user.",
         "steps": "1. Open expense\n2. Look for Edit",
         "test_data": "n/a",
         "expected": "Edit button hidden. Direct API call returns 403.",
         "priority": "High", "severity": "Critical", "platform": "Both"},
        {**base, "id": "TC_EXP_16", "feature": "Delete Expense", "screen": "Expense Detail",
         "scenario": "Payer can delete their expense",
         "description": "Soft delete.",
         "preconditions": "Logged in as payer.",
         "steps": "1. Expense Detail → 🗑\n2. Confirm",
         "test_data": "n/a",
         "expected": "Expense disappears; balances/aggregates update.",
         "platform": "Both"},
        {**base, "id": "TC_EXP_17", "feature": "Delete Expense", "screen": "Expense Detail",
         "scenario": "Group admin can delete any expense",
         "description": "Admin override.",
         "preconditions": "Logged in as group admin (not the payer).",
         "steps": "1. Open someone else's expense\n2. Delete\n3. Confirm",
         "test_data": "n/a",
         "expected": "Deletion succeeds. Activity log shows the admin's action.",
         "platform": "Both"},
        {**base, "id": "TC_EXP_18", "feature": "Expense List", "screen": "Group Detail",
         "scenario": "Pagination loads more expenses on scroll",
         "description": "Limit 50 per page.",
         "preconditions": "Group with >100 expenses.",
         "steps": "1. Open group\n2. Scroll to bottom",
         "test_data": "n/a",
         "expected": "Next page fetched; no duplicates; no jump in scroll position.",
         "priority": "Medium", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_EXP_19", "feature": "Expense List", "screen": "Group Detail",
         "scenario": "Soft-deleted expenses do not appear",
         "description": "deleted_at filter.",
         "preconditions": "Some expenses soft-deleted.",
         "steps": "1. Open group",
         "test_data": "n/a",
         "expected": "Only non-deleted expenses visible.",
         "priority": "High", "severity": "Critical", "platform": "Both"},
        {**base, "id": "TC_EXP_20", "feature": "Categories", "screen": "Add Expense",
         "scenario": "Category picker shows preset list and persists choice",
         "description": "Categories like food, travel, etc.",
         "preconditions": "Add Expense open.",
         "steps": "1. Tap category\n2. Pick 'Food'\n3. Save",
         "test_data": "Food",
         "expected": "Category stored on expense; visible icon on the card.",
         "priority": "Medium", "severity": "Minor", "platform": "Both"},
    ]


def settlements_cases() -> list[dict]:
    base = dict(module="Settlements", priority="High", severity="Critical")
    return [
        {**base, "id": "TC_SET_01", "feature": "Record Settlement", "screen": "Settle Up",
         "scenario": "Settle full outstanding balance to a member",
         "description": "Balance goes to zero.",
         "preconditions": "Owe ₹500 to Atharv in 'Goa Trip'.",
         "steps": "1. Group → Settle Up → Atharv\n2. Amount: 500\n3. Save",
         "test_data": "Amount: 500",
         "expected": "Settlement recorded. Group balance with Atharv = 0. Activity log shows settlement.",
         "platform": "Both"},
        {**base, "id": "TC_SET_02", "feature": "Record Settlement", "screen": "Settle Up",
         "scenario": "Partial settlement updates remaining balance",
         "description": "Less than the owed amount.",
         "preconditions": "Owe ₹500.",
         "steps": "1. Pay 200",
         "test_data": "Amount: 200",
         "expected": "Remaining 300 still owed. Both sides reflect.",
         "platform": "Both"},
        {**base, "id": "TC_SET_03", "feature": "Record Settlement", "screen": "Settle Up",
         "scenario": "Cannot settle more than owed (or warn)",
         "description": "Validation/warning.",
         "preconditions": "Owe 100.",
         "steps": "1. Try 200",
         "test_data": "Amount: 200",
         "expected": "Either blocked OR warning 'This exceeds outstanding balance — continue?'.",
         "priority": "Medium", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_SET_04", "feature": "Settlement History", "screen": "Group Detail",
         "scenario": "Settlement history list ordered newest first",
         "description": "Audit trail.",
         "preconditions": "Multiple settlements exist.",
         "steps": "1. Group → Settlements tab",
         "test_data": "n/a",
         "expected": "Sorted descending by date. Shows payer/payee/amount/date.",
         "platform": "Both"},
        {**base, "id": "TC_SET_05", "feature": "Delete Settlement", "screen": "Settlement Detail",
         "scenario": "Creator can undo settlement",
         "description": "Soft delete reverses balances.",
         "preconditions": "Recent settlement created by current user.",
         "steps": "1. Tap settlement → Delete → confirm",
         "test_data": "n/a",
         "expected": "Settlement removed. Balances restored.",
         "priority": "High", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_SET_06", "feature": "Cross-group Settlement", "screen": "Settle Up",
         "scenario": "Settle multiple groups owed to same person",
         "description": "If supported, single settlement clears across groups.",
         "preconditions": "Owe Atharv in two groups.",
         "steps": "1. Friends → Atharv → Settle\n2. Confirm full amount",
         "test_data": "n/a",
         "expected": "All groups with Atharv show balance = 0.",
         "priority": "Medium", "severity": "Major", "platform": "Both"},
    ]


def activity_cases() -> list[dict]:
    base = dict(module="Activity", priority="Medium", severity="Major")
    return [
        {**base, "id": "TC_ACT_01", "feature": "Activity Feed", "screen": "Activity",
         "scenario": "Recent events appear in feed",
         "description": "Latest expense/settlement/group events.",
         "preconditions": "Logged in.",
         "steps": "1. Open Activity tab",
         "test_data": "n/a",
         "expected": "Feed populated; newest at top; relative timestamps.",
         "platform": "Both"},
        {**base, "id": "TC_ACT_02", "feature": "Filter", "screen": "Activity",
         "scenario": "Filter by Expenses / Settlements / Groups",
         "description": "Type filters.",
         "preconditions": "Mixed events.",
         "steps": "1. Tap filter chip → Expenses\n2. Switch to Settlements\n3. Switch to Groups",
         "test_data": "n/a",
         "expected": "Only matching events shown for each filter.",
         "platform": "Both"},
        {**base, "id": "TC_ACT_03", "feature": "Unread Badge", "screen": "Bottom Nav",
         "scenario": "Unread count badge on Activity tab",
         "description": "FCM/silent push events bump unread count.",
         "preconditions": "Other user added an expense.",
         "steps": "1. Wait for push event\n2. View bottom nav",
         "test_data": "n/a",
         "expected": "Activity tab shows unread count.",
         "priority": "Medium", "severity": "Minor", "platform": "Both"},
        {**base, "id": "TC_ACT_04", "feature": "Mark Read", "screen": "Activity",
         "scenario": "Opening activity marks items read",
         "description": "Best-effort PUT call.",
         "preconditions": "Unread items.",
         "steps": "1. Open Activity tab",
         "test_data": "n/a",
         "expected": "Badge clears. Items remain visible.",
         "priority": "Medium", "severity": "Minor", "platform": "Both"},
        {**base, "id": "TC_ACT_05", "feature": "Deep Link", "screen": "Activity",
         "scenario": "Tap on expense activity opens expense detail",
         "description": "Routing.",
         "preconditions": "Expense activity row.",
         "steps": "1. Tap row",
         "test_data": "n/a",
         "expected": "Expense Detail opens with correct expense.",
         "platform": "Both"},
    ]


def reports_cases() -> list[dict]:
    base = dict(module="Reports", priority="Medium", severity="Major")
    return [
        {**base, "id": "TC_RPT_01", "feature": "View Reports", "screen": "Reports",
         "scenario": "Default report shows current month spending",
         "description": "Bar/pie chart aggregates.",
         "preconditions": "Logged in.",
         "steps": "1. Open Reports",
         "test_data": "n/a",
         "expected": "Total spend, category breakdown, group-wise spend visible.",
         "platform": "Both"},
        {**base, "id": "TC_RPT_02", "feature": "Date Range", "screen": "Reports",
         "scenario": "Switch range (Month / Year / Custom)",
         "description": "Range filters.",
         "preconditions": "Reports open.",
         "steps": "1. Tap range → Year\n2. Tap → Custom → pick last 90 days",
         "test_data": "n/a",
         "expected": "Charts refresh with new totals; no overlap on labels.",
         "platform": "Both"},
        {**base, "id": "TC_RPT_03", "feature": "Export PDF", "screen": "Reports",
         "scenario": "Export current report as PDF",
         "description": "Uses pdf package.",
         "preconditions": "Reports open.",
         "steps": "1. Share/Export → PDF\n2. Choose destination",
         "test_data": "n/a",
         "expected": "PDF generated; readable; has app branding + date range.",
         "priority": "Medium", "severity": "Minor", "platform": "Both"},
        {**base, "id": "TC_RPT_04", "feature": "Empty Range", "screen": "Reports",
         "scenario": "Empty state when no data in range",
         "description": "UX rule.",
         "preconditions": "Pick a range with no expenses.",
         "steps": "1. Custom → years ago",
         "test_data": "n/a",
         "expected": "Friendly empty state, not blank charts.",
         "priority": "Medium", "severity": "Minor", "platform": "Both"},
    ]


def friends_cases() -> list[dict]:
    base = dict(module="Friends", priority="Medium", severity="Major")
    return [
        {**base, "id": "TC_FRD_01", "feature": "Friends List", "screen": "Friends",
         "scenario": "Friends list shows everyone with a non-zero shared balance",
         "description": "Derived from group memberships.",
         "preconditions": "Multiple groups, shared members.",
         "steps": "1. Open Friends tab",
         "test_data": "n/a",
         "expected": "Each friend shows aggregated balance across all shared groups.",
         "platform": "Both"},
        {**base, "id": "TC_FRD_02", "feature": "Friend Detail", "screen": "Friend Detail",
         "scenario": "Friend detail breaks down per group",
         "description": "Per-group balance and recent activity.",
         "preconditions": "Tap a friend.",
         "steps": "1. Tap friend",
         "test_data": "n/a",
         "expected": "Shows per-group balance, group cards, settle-up CTA.",
         "platform": "Both"},
        {**base, "id": "TC_FRD_03", "feature": "Settle from Friend", "screen": "Friend Detail",
         "scenario": "Settle button routes to /settle/:userId",
         "description": "Direct settlement.",
         "preconditions": "Non-zero balance.",
         "steps": "1. Tap Settle Up",
         "test_data": "n/a",
         "expected": "Settle screen opens prefilled with that friend.",
         "platform": "Both"},
    ]


def api_cases() -> list[dict]:
    base = dict(module="API Validation", priority="High", severity="Major")
    return [
        {**base, "id": "TC_API_01", "feature": "Response Envelope", "screen": "n/a",
         "scenario": "All successful responses are { success: true, data, message? }",
         "description": "Contract verification.",
         "preconditions": "Charles/Proxyman attached.",
         "steps": "1. Trigger any API call\n2. Inspect response body",
         "test_data": "n/a",
         "expected": "Body shape matches contract; client parses successfully.",
         "platform": "Both"},
        {**base, "id": "TC_API_02", "feature": "Error Envelope", "screen": "n/a",
         "scenario": "Errors come as { success: false, error, details? }",
         "description": "Contract verification.",
         "preconditions": "Trigger 400/401/403/404.",
         "steps": "1. Send a malformed POST",
         "test_data": "n/a",
         "expected": "Backend returns error envelope; client surfaces error.message.",
         "platform": "Both"},
        {**base, "id": "TC_API_03", "feature": "Auth Header", "screen": "n/a",
         "scenario": "Authorization: Bearer <token> on every authenticated call",
         "description": "Header attached by interceptor.",
         "preconditions": "Logged in.",
         "steps": "1. Capture any /v1 request",
         "test_data": "n/a",
         "expected": "Authorization header present with valid JWT.",
         "platform": "Both"},
        {**base, "id": "TC_API_04", "feature": "401 Refresh", "screen": "n/a",
         "scenario": "On 401, /auth/refresh fires and original request retries once",
         "description": "Interceptor logic.",
         "preconditions": "Access token expired.",
         "steps": "1. Open any data screen",
         "test_data": "n/a",
         "expected": "Sequence in proxy: 401 → POST /auth/refresh → original request retried.",
         "priority": "High", "severity": "Critical", "platform": "Both"},
        {**base, "id": "TC_API_05", "feature": "Rate Limit", "screen": "n/a",
         "scenario": "429 returned after exceeding rate limit",
         "description": "200 req/min global.",
         "preconditions": "Hit a single endpoint rapidly.",
         "steps": "1. Loop 300 GET /expenses calls",
         "test_data": "n/a",
         "expected": "From ~201st request, server returns 429 with retry-after.",
         "platform": "Both"},
        {**base, "id": "TC_API_06", "feature": "Payload Size", "screen": "n/a",
         "scenario": "Body > 2MB rejected with 413",
         "description": "express.json limit.",
         "preconditions": "Send a large base64 receipt.",
         "steps": "1. Attach receipt 5MB pre-compression\n2. Save expense",
         "test_data": "n/a",
         "expected": "If client compresses → <2MB ok. If forced raw → 413 from server; UI shows friendly error.",
         "priority": "Medium", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_API_07", "feature": "TLS / HTTPS", "screen": "n/a",
         "scenario": "All production API calls use HTTPS",
         "description": "ATS / cleartext disabled.",
         "preconditions": "Release build pointed at production.",
         "steps": "1. Inspect every URL in proxy",
         "test_data": "n/a",
         "expected": "Every URL begins with https://. No cleartext traffic.",
         "priority": "High", "severity": "Critical", "platform": "Both"},
        {**base, "id": "TC_API_08", "feature": "Timeouts", "screen": "n/a",
         "scenario": "Connection timeout after 10s; receive after 20s",
         "description": "Dio timeouts in ApiConfig.",
         "preconditions": "Throttle network.",
         "steps": "1. Block server\n2. Trigger any call",
         "test_data": "n/a",
         "expected": "Timeout error surfaced cleanly; retry available.",
         "priority": "Medium", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_API_09", "feature": "Pagination", "screen": "n/a",
         "scenario": "List endpoints return pagination object",
         "description": "{ page, limit, total, hasMore }.",
         "preconditions": "Logged in.",
         "steps": "1. GET /expenses?groupId=...&page=1&limit=20",
         "test_data": "n/a",
         "expected": "Response has pagination block; hasMore correctly true/false.",
         "platform": "Both"},
        {**base, "id": "TC_API_10", "feature": "Cache Invalidation", "screen": "n/a",
         "scenario": "Adding an expense invalidates dashboard balance immediately",
         "description": "No stale read.",
         "preconditions": "Open Dashboard before adding expense.",
         "steps": "1. Note balance\n2. Add expense in another group\n3. Pull-to-refresh Dashboard",
         "test_data": "n/a",
         "expected": "Balance reflects new expense without waiting for TTL.",
         "priority": "High", "severity": "Major", "platform": "Both"},
    ]


def push_cases() -> list[dict]:
    base = dict(module="Push Notifications", priority="High", severity="Major")
    return [
        {**base, "id": "TC_PSH_01", "feature": "FCM Permission", "screen": "Splash / Onboarding",
         "scenario": "Permission prompt shown once on first launch",
         "description": "POST_NOTIFICATIONS on Android 13+ / Apple permission on iOS.",
         "preconditions": "Fresh install.",
         "steps": "1. Launch app\n2. Observe permission prompt",
         "test_data": "n/a",
         "expected": "Prompt shown. Choice persists.",
         "platform": "Both"},
        {**base, "id": "TC_PSH_02", "feature": "FCM Token", "screen": "n/a",
         "scenario": "FCM token registered with backend on login",
         "description": "fcm_token saved on user.",
         "preconditions": "Logged in; permission granted.",
         "steps": "1. Capture PATCH /users/me request",
         "test_data": "n/a",
         "expected": "Body contains fcmToken. Backend stores it.",
         "platform": "Both"},
        {**base, "id": "TC_PSH_03", "feature": "Foreground Push", "screen": "Any",
         "scenario": "Notification when app is foreground shows in-app banner",
         "description": "Local foreground display.",
         "preconditions": "App open in foreground.",
         "steps": "1. Trigger a push from Firebase console",
         "test_data": "n/a",
         "expected": "In-app banner/snackbar visible; no system tray on iOS.",
         "platform": "Both"},
        {**base, "id": "TC_PSH_04", "feature": "Background Push", "screen": "n/a",
         "scenario": "Push received while backgrounded — system notification shown",
         "description": "Standard FCM.",
         "preconditions": "App backgrounded.",
         "steps": "1. Send push",
         "test_data": "n/a",
         "expected": "System notification with app icon. Tap navigates to deep link.",
         "platform": "Both"},
        {**base, "id": "TC_PSH_05", "feature": "Killed App Push", "screen": "n/a",
         "scenario": "Push received while app killed routes to correct screen on tap",
         "description": "Cold start with intent.",
         "preconditions": "App force-stopped.",
         "steps": "1. Send push\n2. Tap notification",
         "test_data": "n/a",
         "expected": "App opens directly to deep link (e.g. /home/groups/<id>).",
         "priority": "High", "severity": "Critical", "platform": "Both"},
        {**base, "id": "TC_PSH_06", "feature": "Notification Categories", "screen": "n/a",
         "scenario": "Expense vs Settlement vs Member-added notifications styled correctly",
         "description": "Different message bodies and routes.",
         "preconditions": "Trigger each type.",
         "steps": "1. Send three different types",
         "test_data": "n/a",
         "expected": "Each shows correct title, body, and routes correctly on tap.",
         "platform": "Both"},
        {**base, "id": "TC_PSH_07", "feature": "Denied Permission", "screen": "Any",
         "scenario": "Denying notifications doesn't crash; app still works",
         "description": "Permission denial gracefully handled.",
         "preconditions": "Permission denied.",
         "steps": "1. Use the app",
         "test_data": "n/a",
         "expected": "All flows work; an in-app prompt encourages re-enabling.",
         "priority": "Medium", "severity": "Major", "platform": "Both"},
    ]


def deeplink_cases() -> list[dict]:
    base = dict(module="Deep Links", priority="Medium", severity="Major")
    return [
        {**base, "id": "TC_DL_01", "feature": "WhatsApp Invite Link", "screen": "n/a",
         "scenario": "Tapping invite link routes to Onboarding/Register with prefilled group join",
         "description": "Invite delivered via WATI carries a deep link.",
         "preconditions": "WATI invite received.",
         "steps": "1. Tap link from WhatsApp\n2. Follow registration",
         "test_data": "n/a",
         "expected": "Post-registration, user lands in the inviting group automatically.",
         "platform": "Both"},
        {**base, "id": "TC_DL_02", "feature": "Push Deep Link", "screen": "n/a",
         "scenario": "Push payload route='/home/groups/<id>' opens that group",
         "description": "Notification router.",
         "preconditions": "Push received.",
         "steps": "1. Tap push",
         "test_data": "n/a",
         "expected": "App opens Group Detail for the right group.",
         "platform": "Both"},
        {**base, "id": "TC_DL_03", "feature": "Invalid Deep Link", "screen": "n/a",
         "scenario": "Bad route shown as 'Not Found' instead of crashing",
         "description": "Graceful 404.",
         "preconditions": "Send a push with route='/garbage'.",
         "steps": "1. Tap notification",
         "test_data": "n/a",
         "expected": "App opens Dashboard or a 'Not Found' screen; no crash.",
         "priority": "High", "severity": "Major", "platform": "Both"},
    ]


def permissions_cases() -> list[dict]:
    base = dict(module="Permissions", priority="High", severity="Major")
    return [
        {**base, "id": "TC_PRM_01", "feature": "Camera", "screen": "Add Expense",
         "scenario": "First camera use shows OS prompt with usage description",
         "description": "iOS NSCameraUsageDescription / Android camera runtime permission.",
         "preconditions": "Camera never used before.",
         "steps": "1. Add Expense → 📎 → Camera",
         "test_data": "n/a",
         "expected": "OS prompt shows reason; Allow opens camera; Deny stays on Add Expense.",
         "platform": "Both"},
        {**base, "id": "TC_PRM_02", "feature": "Camera Denied", "screen": "Add Expense",
         "scenario": "Camera denied → in-app banner + Settings deep link",
         "description": "Don't repeatedly nag; guide user.",
         "preconditions": "Camera permission denied permanently.",
         "steps": "1. Tap Camera",
         "test_data": "n/a",
         "expected": "Banner 'Camera access needed — open Settings'. Tapping opens app settings.",
         "platform": "Both"},
        {**base, "id": "TC_PRM_03", "feature": "Photos / Gallery", "screen": "Add Expense",
         "scenario": "Photo permission prompt with correct iOS strings (read + add-only)",
         "description": "Two iOS usage strings: NSPhotoLibrary + NSPhotoLibraryAddOnly.",
         "preconditions": "Fresh install.",
         "steps": "1. Tap Gallery to pick receipt\n2. Try Save as image elsewhere",
         "test_data": "n/a",
         "expected": "Read prompt shown when picking; add-only when saving; correct usage text from Info.plist.",
         "platform": "Both"},
        {**base, "id": "TC_PRM_04", "feature": "Contacts", "screen": "Add Members",
         "scenario": "Contacts permission prompt with usage text",
         "description": "NSContactsUsageDescription.",
         "preconditions": "Fresh install.",
         "steps": "1. Create Group → Add from contacts",
         "test_data": "n/a",
         "expected": "OS prompt shown; Allow lists contacts; Deny shows manual phone entry option.",
         "platform": "Both"},
        {**base, "id": "TC_PRM_05", "feature": "Notifications", "screen": "First Launch",
         "scenario": "Notification permission requested at right moment",
         "description": "Not too aggressive — should explain value first.",
         "preconditions": "Fresh install.",
         "steps": "1. Launch app first time",
         "test_data": "n/a",
         "expected": "Prompt shown after a soft pre-prompt explaining benefit (not blindly on launch).",
         "priority": "Medium", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_PRM_06", "feature": "Microphone", "screen": "n/a (if voice notes)",
         "scenario": "If feature absent — no Microphone permission declared",
         "description": "Hygiene: don't ask for what you don't use.",
         "preconditions": "Inspect Info.plist + AndroidManifest.",
         "steps": "1. Inspect manifests",
         "test_data": "n/a",
         "expected": "No Microphone permission strings unless feature exists.",
         "priority": "Medium", "severity": "Minor", "platform": "Both"},
        {**base, "id": "TC_PRM_07", "feature": "Location", "screen": "n/a",
         "scenario": "Location permission NOT requested (app doesn't use it)",
         "description": "Hygiene.",
         "preconditions": "Inspect manifests.",
         "steps": "1. Inspect",
         "test_data": "n/a",
         "expected": "No location strings or permissions present.",
         "priority": "Medium", "severity": "Minor", "platform": "Both"},
        {**base, "id": "TC_PRM_08", "feature": "Bluetooth", "screen": "n/a",
         "scenario": "Bluetooth permission NOT requested",
         "description": "Hygiene.",
         "preconditions": "Inspect manifests.",
         "steps": "1. Inspect",
         "test_data": "n/a",
         "expected": "No bluetooth permission present.",
         "priority": "Low", "severity": "Minor", "platform": "Both"},
    ]


def offline_cases() -> list[dict]:
    base = dict(module="Offline / Network", priority="High", severity="Major")
    return [
        {**base, "id": "TC_OFF_01", "feature": "Offline Banner", "screen": "Global",
         "scenario": "Banner appears when device goes offline",
         "description": "ConnectivityService + OfflineBanner overlay.",
         "preconditions": "Network on.",
         "steps": "1. Enable airplane mode",
         "test_data": "n/a",
         "expected": "Banner 'You're offline' appears within 3s at top of every route.",
         "platform": "Both"},
        {**base, "id": "TC_OFF_02", "feature": "Offline Mutation Block", "screen": "Add Expense",
         "scenario": "Save attempts blocked offline with friendly message",
         "description": "OfflineInterceptor short-circuits Dio calls.",
         "preconditions": "Offline.",
         "steps": "1. Add Expense → Save",
         "test_data": "n/a",
         "expected": "Snackbar 'You're offline — try again when connected'. Form retains data.",
         "platform": "Both"},
        {**base, "id": "TC_OFF_03", "feature": "Reconnect", "screen": "Global",
         "scenario": "Banner dismisses + queued actions retry on reconnect",
         "description": "Reconnection handling.",
         "preconditions": "Offline.",
         "steps": "1. Disable airplane mode\n2. Wait 5s",
         "test_data": "n/a",
         "expected": "Banner dismisses. Pending data reloads.",
         "priority": "High", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_OFF_04", "feature": "Slow 3G", "screen": "Dashboard",
         "scenario": "App degrades gracefully on slow networks",
         "description": "Shimmer + timeout handling.",
         "preconditions": "Network throttled to Slow 3G.",
         "steps": "1. Open Dashboard",
         "test_data": "n/a",
         "expected": "Loading state visible; eventual success or graceful timeout error.",
         "priority": "Medium", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_OFF_05", "feature": "Cached Reads", "screen": "Groups",
         "scenario": "Cached group list visible while offline (if cache implemented)",
         "description": "Last fetched data preserved.",
         "preconditions": "Visited Groups once online.",
         "steps": "1. Go offline\n2. Open Groups",
         "test_data": "n/a",
         "expected": "List shown (stale flag if applicable). Tap details: 'Cached — offline' notice.",
         "priority": "Medium", "severity": "Minor", "platform": "Both"},
    ]


def performance_cases() -> list[dict]:
    base = dict(module="Performance", priority="Medium", severity="Major")
    return [
        {**base, "id": "TC_PRF_01", "feature": "Cold Start", "screen": "Splash",
         "scenario": "Cold start TTID < 3 s on a mid-range device",
         "description": "Time to interactive Dashboard.",
         "preconditions": "App fresh launch.",
         "steps": "1. Force-stop app\n2. Tap icon\n3. Measure time to Dashboard",
         "test_data": "Mid-range Android (Snapdragon 6-series) / iPhone SE",
         "expected": "Under 3 seconds in best case, under 5 seconds in cold cache.",
         "platform": "Both"},
        {**base, "id": "TC_PRF_02", "feature": "Hot Start", "screen": "Any",
         "scenario": "Returning to foreground is instant (<500ms)",
         "description": "No reload on resume.",
         "preconditions": "App backgrounded.",
         "steps": "1. Background app\n2. Resume",
         "test_data": "n/a",
         "expected": "App resumes to previous screen instantly.",
         "platform": "Both"},
        {**base, "id": "TC_PRF_03", "feature": "Scroll Performance", "screen": "Expenses list",
         "scenario": "60fps scrolling on 200+ items",
         "description": "ListView.builder hygiene.",
         "preconditions": "Group with 200+ expenses.",
         "steps": "1. Flick-scroll the list",
         "test_data": "n/a",
         "expected": "No visible jank. Profiler shows >55fps avg.",
         "platform": "Both"},
        {**base, "id": "TC_PRF_04", "feature": "Memory", "screen": "Any",
         "scenario": "Memory usage stays under 250MB during typical session",
         "description": "Image cache hygiene.",
         "preconditions": "Use app for ~10 minutes.",
         "steps": "1. Open all main flows\n2. Inspect profiler",
         "test_data": "n/a",
         "expected": "Memory remains stable; no leak per route.",
         "priority": "Medium", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_PRF_05", "feature": "Network Efficiency", "screen": "n/a",
         "scenario": "No N+1 calls — list views fetch in single request + batched children",
         "description": "Verified via proxy.",
         "preconditions": "Proxy attached.",
         "steps": "1. Open Group Detail (50 expenses)",
         "test_data": "n/a",
         "expected": "1 list call + 1 batched participants call. NOT 50 per-expense calls.",
         "platform": "Both"},
    ]


def security_cases() -> list[dict]:
    base = dict(module="Security", priority="High", severity="Critical")
    return [
        {**base, "id": "TC_SEC_01", "feature": "Token Storage", "screen": "n/a",
         "scenario": "Access/refresh tokens stored in Keychain (iOS) / Keystore (Android)",
         "description": "flutter_secure_storage used.",
         "preconditions": "Logged in.",
         "steps": "1. Inspect device-level storage (rooted device or emulator)",
         "test_data": "n/a",
         "expected": "Tokens NOT in SharedPreferences/UserDefaults plain. Encrypted at rest.",
         "platform": "Both"},
        {**base, "id": "TC_SEC_02", "feature": "HTTPS Enforcement", "screen": "n/a",
         "scenario": "App refuses HTTP for production base URL",
         "description": "ATS + usesCleartextTraffic=false.",
         "preconditions": "Try forcing HTTP via proxy.",
         "steps": "1. Set proxy to redirect to http://...",
         "test_data": "n/a",
         "expected": "Connection blocked. App surfaces error.",
         "platform": "Both"},
        {**base, "id": "TC_SEC_03", "feature": "App Switcher Privacy", "screen": "Any",
         "scenario": "Sensitive screens blurred in app switcher",
         "description": "Finance app rule.",
         "preconditions": "On Dashboard.",
         "steps": "1. Open app switcher (iOS/Android)",
         "test_data": "n/a",
         "expected": "Snapshot blurred / hidden balances.",
         "platform": "Both"},
        {**base, "id": "TC_SEC_04", "feature": "Log Hygiene", "screen": "n/a",
         "scenario": "Release build does not log JWTs, OTPs, passwords",
         "description": "Inspect logcat / Console.",
         "preconditions": "Release build installed.",
         "steps": "1. Trigger login flow\n2. View logs",
         "test_data": "n/a",
         "expected": "No raw secrets in logs.",
         "platform": "Both"},
        {**base, "id": "TC_SEC_05", "feature": "Deeplink Auth Gate", "screen": "n/a",
         "scenario": "Authenticated routes blocked when not logged in",
         "description": "Direct deep link without auth must redirect to login.",
         "preconditions": "Logged out.",
         "steps": "1. Tap an FCM link for /home/groups/<id>",
         "test_data": "n/a",
         "expected": "App routes to Login first; after login, lands on target.",
         "platform": "Both"},
        {**base, "id": "TC_SEC_06", "feature": "Cross-User Authorization", "screen": "n/a",
         "scenario": "Group A admin cannot edit/delete expenses in Group B",
         "description": "Backend ACLs.",
         "preconditions": "Two groups, two users.",
         "steps": "1. As admin of A, attempt PUT /expenses/<id from B>",
         "test_data": "n/a",
         "expected": "403 returned. UI shows access denied if attempted via link.",
         "platform": "Both"},
        {**base, "id": "TC_SEC_07", "feature": "Input Sanitization", "screen": "Various",
         "scenario": "Group name with HTML/script tags rendered as plain text",
         "description": "No XSS in displayed text.",
         "preconditions": "Logged in.",
         "steps": "1. Create group with name '<script>alert(1)</script>'",
         "test_data": "Malicious name",
         "expected": "Displayed as literal characters. No execution.",
         "platform": "Both"},
        {**base, "id": "TC_SEC_08", "feature": "Rate-Limited Endpoints", "screen": "n/a",
         "scenario": "Login / OTP / Reset password each rate-limited per phone",
         "description": "Prevents brute force.",
         "preconditions": "n/a",
         "steps": "1. Spam OTP request for same phone",
         "test_data": "Same phone, rapid taps",
         "expected": "Backend trips rate limit. UI shows cool-down.",
         "platform": "Both"},
    ]


def payment_cases() -> list[dict]:
    base = dict(module="Payment Flow", priority="Medium", severity="Major")
    return [
        {**base, "id": "TC_PAY_01", "feature": "Payment Integration", "screen": "n/a",
         "scenario": "NOT APPLICABLE — app records settlements, no payment gateway in current scope",
         "description": "Add cases here when UPI / Stripe / Razorpay is integrated.",
         "preconditions": "n/a",
         "steps": "n/a",
         "test_data": "n/a",
         "expected": "Mark as N/A unless a payment gateway is wired.",
         "priority": "Low", "severity": "Minor", "platform": "Both", "status": "Not Tested",
         "remarks": "Placeholder for future payment integration."},
    ]


def subscription_cases() -> list[dict]:
    base = dict(module="Subscription", priority="Low", severity="Minor")
    return [
        {**base, "id": "TC_SUB_01", "feature": "Subscription", "screen": "n/a",
         "scenario": "NOT APPLICABLE — no subscription tier in current product",
         "description": "Add cases here when Pro/Premium plans are introduced.",
         "preconditions": "n/a",
         "steps": "n/a",
         "test_data": "n/a",
         "expected": "Mark as N/A unless subscription feature is built.",
         "platform": "Both", "status": "Not Tested",
         "remarks": "Placeholder for future subscription tier."},
    ]


def settings_cases() -> list[dict]:
    base = dict(module="Settings", priority="Medium", severity="Minor")
    return [
        {**base, "id": "TC_STG_01", "feature": "Theme", "screen": "Settings",
         "scenario": "Switch theme: system / light / dark",
         "description": "ThemeMode applied app-wide.",
         "preconditions": "Logged in.",
         "steps": "1. Settings → Theme → Dark\n2. Restart app",
         "test_data": "Dark",
         "expected": "Dark theme persists across restart. UI passes contrast checks.",
         "platform": "Both"},
        {**base, "id": "TC_STG_02", "feature": "Currency Default", "screen": "Settings",
         "scenario": "Default currency preference",
         "description": "Persists to user profile.",
         "preconditions": "Logged in.",
         "steps": "1. Settings → Currency → USD\n2. Re-open Add Expense without group",
         "test_data": "USD",
         "expected": "Add Expense defaults to USD.",
         "platform": "Both"},
        {**base, "id": "TC_STG_03", "feature": "Notifications", "screen": "Settings",
         "scenario": "Toggle push categories (expenses / settlements / invites)",
         "description": "Per-category opt-out.",
         "preconditions": "Logged in.",
         "steps": "1. Settings → Notifications\n2. Toggle off Invites",
         "test_data": "Invites OFF",
         "expected": "User does not receive invite-type pushes (verify via console send).",
         "platform": "Both"},
        {**base, "id": "TC_STG_04", "feature": "Delete Account", "screen": "Settings",
         "scenario": "Delete account with confirmation (regulatory requirement)",
         "description": "Soft delete + token revocation.",
         "preconditions": "Logged in.",
         "steps": "1. Settings → Delete Account → confirm twice",
         "test_data": "n/a",
         "expected": "Account soft-deleted. User logged out. Re-registering with same phone shows fresh state.",
         "priority": "High", "severity": "Critical", "platform": "Both"},
        {**base, "id": "TC_STG_05", "feature": "About / Legal", "screen": "Settings",
         "scenario": "Terms of Service and Privacy Policy links open in browser",
         "description": "Legal compliance.",
         "preconditions": "Settings open.",
         "steps": "1. Tap Terms of Service\n2. Back\n3. Tap Privacy Policy",
         "test_data": "n/a",
         "expected": "Both open valid pages in external browser.",
         "platform": "Both"},
    ]


def crash_cases() -> list[dict]:
    base = dict(module="Crash & Exception", priority="High", severity="Critical")
    return [
        {**base, "id": "TC_CRS_01", "feature": "Crashlytics Init", "screen": "Splash",
         "scenario": "Crashlytics records a forced test crash",
         "description": "Verify Crashlytics pipeline.",
         "preconditions": "Release build with Crashlytics enabled.",
         "steps": "1. Trigger forced crash button (debug hidden gesture if exists)\n2. Reopen\n3. Check Firebase Crashlytics console after 10 min",
         "test_data": "n/a",
         "expected": "Crash visible in Crashlytics with stack trace.",
         "platform": "Both"},
        {**base, "id": "TC_CRS_02", "feature": "Graceful Recovery", "screen": "Various",
         "scenario": "Forced kill mid-form preserves draft (if implemented)",
         "description": "Draft-save behavior.",
         "preconditions": "On Add Expense.",
         "steps": "1. Fill some fields\n2. Force-stop\n3. Reopen",
         "test_data": "n/a",
         "expected": "Draft restored OR clean form depending on spec — must not crash.",
         "priority": "Medium", "severity": "Major", "platform": "Both"},
        {**base, "id": "TC_CRS_03", "feature": "Malformed Backend Data", "screen": "Various",
         "scenario": "Unexpected response shape does not crash UI",
         "description": "fromJson resilience.",
         "preconditions": "Proxy injects malformed response.",
         "steps": "1. Rewrite response to remove a required field\n2. Open the screen",
         "test_data": "Malformed JSON",
         "expected": "Error state shown; no crash.",
         "platform": "Both"},
        {**base, "id": "TC_CRS_04", "feature": "Low Memory Kill", "screen": "Various",
         "scenario": "App resumes correctly after OS reclaims it",
         "description": "Android low-memory recreation.",
         "preconditions": "App backgrounded; trigger Don't Keep Activities (Dev options).",
         "steps": "1. Open developer Don't Keep Activities\n2. Open app → go to Group Detail\n3. Background\n4. Open another heavy app to trigger memory pressure\n5. Resume",
         "test_data": "n/a",
         "expected": "App resumes to Group Detail with state intact; no white screen or crash.",
         "priority": "High", "severity": "Major", "platform": "Android"},
        {**base, "id": "TC_CRS_05", "feature": "Rotation", "screen": "Add Expense",
         "scenario": "Rotation preserves form fields",
         "description": "configChanges declared in manifest.",
         "preconditions": "Add Expense partially filled.",
         "steps": "1. Rotate to landscape\n2. Rotate back",
         "test_data": "n/a",
         "expected": "Form values preserved.",
         "platform": "Both"},
    ]


def cross_platform_cases() -> list[dict]:
    base = dict(module="Cross-Platform", priority="High", severity="Major")
    return [
        # Android specific
        {**base, "id": "TC_AND_01", "feature": "Android Versions", "screen": "Global",
         "scenario": "Smoke test on Android 10 / 12 / 14",
         "description": "Cover spread of API levels.",
         "preconditions": "Devices/emulators available.",
         "steps": "1. Install build on each\n2. Run smoke flow: login → group → add expense → settle",
         "test_data": "n/a",
         "expected": "Smoke flow passes on all three.",
         "platform": "Android"},
        {**base, "id": "TC_AND_02", "feature": "Edge-to-Edge", "screen": "Global",
         "scenario": "Android 15 enforces edge-to-edge — no overlap with system bars",
         "description": "Status/nav bars compensate.",
         "preconditions": "Android 15 device.",
         "steps": "1. Open every primary screen",
         "test_data": "n/a",
         "expected": "Content respects safe insets; no clipped buttons.",
         "platform": "Android"},
        {**base, "id": "TC_AND_03", "feature": "Back Predictive", "screen": "Global",
         "scenario": "Android 14+ predictive back animation does not crash routes",
         "description": "go_router back behavior.",
         "preconditions": "Predictive back enabled.",
         "steps": "1. Swipe predictive back from each screen",
         "test_data": "n/a",
         "expected": "Animation smooth; no exceptions.",
         "priority": "Medium", "severity": "Major", "platform": "Android"},
        # iOS specific
        {**base, "id": "TC_IOS_01", "feature": "iOS Versions", "screen": "Global",
         "scenario": "Smoke test on iOS 15 / 16 / 17 / 18",
         "description": "Min target is iOS 15.0.",
         "preconditions": "Multiple devices/simulators.",
         "steps": "1. Install build on each\n2. Run smoke flow",
         "test_data": "n/a",
         "expected": "Smoke passes on all supported versions.",
         "platform": "iOS"},
        {**base, "id": "TC_IOS_02", "feature": "Dynamic Type", "screen": "Global",
         "scenario": "App scales with iOS Dynamic Type (Large → AX1)",
         "description": "Accessibility.",
         "preconditions": "Settings → Accessibility → Text Size.",
         "steps": "1. Set largest accessibility text\n2. Open all screens",
         "test_data": "n/a",
         "expected": "No truncated buttons; layout reflows; no overlap.",
         "priority": "Medium", "severity": "Major", "platform": "iOS"},
        {**base, "id": "TC_IOS_03", "feature": "Privacy Manifest", "screen": "n/a",
         "scenario": "PrivacyInfo.xcprivacy declares all collected data + required reason APIs",
         "description": "Apple privacy requirement for new submissions.",
         "preconditions": "Build artifact.",
         "steps": "1. Validate via Xcode → Build → Validate App\n2. Inspect PrivacyInfo.xcprivacy",
         "test_data": "n/a",
         "expected": "No warnings/errors. Categories: Phone, Name, Email, Photos, Contacts, DeviceID, UserContent, CrashData. APIs: UserDefaults, FileTimestamp, DiskSpace, SystemBootTime.",
         "platform": "iOS"},
        {**base, "id": "TC_IOS_04", "feature": "Tablet Layout", "screen": "Global",
         "scenario": "iPad layout uses Standard (sidebar) layout",
         "description": "Width >= 600.",
         "preconditions": "iPad device/simulator.",
         "steps": "1. Run on iPad",
         "test_data": "n/a",
         "expected": "Sidebar visible, content centered. Rotation preserves layout.",
         "platform": "iOS"},
        {**base, "id": "TC_IOS_05", "feature": "Background Modes", "screen": "n/a",
         "scenario": "Remote notifications and fetch background modes declared",
         "description": "UIBackgroundModes in Info.plist.",
         "preconditions": "Inspect Info.plist.",
         "steps": "1. Read Info.plist",
         "test_data": "n/a",
         "expected": "remote-notification + fetch declared. App receives push when backgrounded.",
         "priority": "Medium", "severity": "Major", "platform": "iOS"},
    ]


# ---------------------------------------------------------------------------
# COVER SHEET
# ---------------------------------------------------------------------------


def build_cover(wb: Workbook) -> None:
    ws = wb.active
    ws.title = "Cover"
    ws.sheet_view.showGridLines = False

    ws.column_dimensions["A"].width = 4
    ws.column_dimensions["B"].width = 32
    ws.column_dimensions["C"].width = 58

    ws.cell(row=2, column=2, value="KharchaSplit — End-to-End QA Test Report")
    ws.cell(row=2, column=2).font = Font(name="Calibri", size=22, bold=True, color=NAVY)
    ws.merge_cells(start_row=2, start_column=2, end_row=2, end_column=3)

    ws.cell(row=3, column=2, value="Mobile App QA Document — Android & iOS")
    ws.cell(row=3, column=2).font = Font(name="Calibri", size=12, italic=True, color="595959")
    ws.merge_cells(start_row=3, start_column=2, end_row=3, end_column=3)

    meta_rows = [
        ("Application", "KharchaSplit (Flutter)"),
        ("Platforms", "Android (min API 24) · iOS (min 15.0)"),
        ("Backend", "Node.js + Express + PostgreSQL"),
        ("Document Owner", "QA Lead"),
        ("Document Version", "1.0"),
        ("Generated On", date.today().isoformat()),
        ("Recommended Devices",
         "Android: Pixel 6 (14) · Samsung A54 (13) · OnePlus Nord (12)\n"
         "iOS: iPhone 13 · iPhone 15 Pro · iPad Air (M2)"),
        ("Tools",
         "Charles Proxy / Proxyman, Firebase Test Lab, BrowserStack, Xcode Instruments, Android Studio Profiler"),
        ("Build Source", "TestFlight build / Play Internal Track"),
    ]
    for i, (label, value) in enumerate(meta_rows, start=5):
        ws.cell(row=i, column=2, value=label)
        ws.cell(row=i, column=2).font = Font(name="Calibri", size=11, bold=True, color="000000")
        ws.cell(row=i, column=2).fill = PatternFill("solid", fgColor=LIGHT_BLUE)
        ws.cell(row=i, column=2).alignment = LEFT_CENTER
        ws.cell(row=i, column=2).border = ALL_BORDERS

        ws.cell(row=i, column=3, value=value)
        ws.cell(row=i, column=3).font = BODY_FONT
        ws.cell(row=i, column=3).alignment = WRAP_TOP
        ws.cell(row=i, column=3).border = ALL_BORDERS
        ws.row_dimensions[i].height = 28 if "\n" in value else 22

    # Section: How to use
    start = 5 + len(meta_rows) + 1
    ws.cell(row=start, column=2, value="How to use this workbook")
    ws.cell(row=start, column=2).font = SUBTITLE_FONT
    ws.merge_cells(start_row=start, start_column=2, end_row=start, end_column=3)

    instructions = [
        "1.  Open the relevant module sheet and pick a test case row.",
        "2.  Fill Tester Name, Device Name, OS Version, Build Version BEFORE you start.",
        "3.  Follow Test Steps; record Actual Result and Status (dropdown).",
        "4.  If Fail: log defect on '24_Bug_Tracker' sheet and put the Defect ID back here.",
        "5.  Attach evidence link (Drive / Slack / Jira) in 'Evidence Link' column.",
        "6.  On retest, update Retest Status and Remarks.",
        "7.  At end of cycle, complete '23_Release_Readiness' + '22_UAT_Signoff'.",
        "8.  '25_Test_Summary' tracks pass/fail totals — review with PM before sign-off.",
    ]
    for i, line in enumerate(instructions, start=start + 1):
        c = ws.cell(row=i, column=2, value=line)
        c.font = BODY_FONT
        c.alignment = WRAP_TOP
        ws.merge_cells(start_row=i, start_column=2, end_row=i, end_column=3)

    # Sheet index
    idx_start = start + len(instructions) + 2
    ws.cell(row=idx_start, column=2, value="Sheets in this workbook")
    ws.cell(row=idx_start, column=2).font = SUBTITLE_FONT
    ws.merge_cells(start_row=idx_start, start_column=2, end_row=idx_start, end_column=3)

    sheets_index = [
        ("01_Authentication", "Signup, Login, OTP, Forgot Password, Social, Session, Logout"),
        ("02_User_Profile", "Profile view + edit, avatar, password change"),
        ("03_Dashboard", "Aggregate balances, recent activity, empty/error states"),
        ("04_Navigation", "Bottom nav, sidebar, hardware back, swipe back, deep routes"),
        ("05_Groups", "Create/edit/archive/delete, members, invites, roles"),
        ("06_Expenses", "Add/edit/delete, splits (equal/exact/percent/shares), receipts"),
        ("07_Settlements", "Record/partial/full, history, undo, cross-group"),
        ("08_Activity", "Feed, filters, unread badge, deep links"),
        ("09_Reports", "Charts, ranges, PDF export"),
        ("10_Friends", "Friend list, per-group balances, settle"),
        ("11_API_Validation", "Envelope, auth, refresh, rate-limit, pagination, cache"),
        ("12_Push_Notifications", "Permission, FCM token, foreground/background/killed"),
        ("13_Deep_Links", "WhatsApp invite link, push routes, invalid routes"),
        ("14_Permissions", "Camera, Photos, Contacts, Notifications + hygiene checks"),
        ("15_Offline_Network", "Banner, mutation block, reconnect, throttle, cache"),
        ("16_Performance", "Cold/hot start, scroll, memory, network efficiency"),
        ("17_Security", "Token storage, HTTPS, app-switcher privacy, ACLs, XSS"),
        ("18_Payment", "Placeholder — no payment integration in current scope"),
        ("19_Subscription", "Placeholder — no subscription tier in current scope"),
        ("20_Settings", "Theme, currency, notifications, delete account, legal"),
        ("21_Crash_Exception", "Crashlytics, recovery, malformed data, low memory"),
        ("22_Cross_Platform", "Android-specific + iOS-specific tests"),
        ("23_Regression_Checklist", "Quick smoke for every release"),
        ("24_UAT_Signoff", "Stakeholder approval"),
        ("25_Release_Readiness", "Go/no-go checklist"),
        ("26_Bug_Tracker", "Defect log — referenced by test case rows"),
        ("27_Test_Summary", "Live dashboard — counts/percentages"),
    ]
    for i, (sheet, desc) in enumerate(sheets_index, start=idx_start + 1):
        ws.cell(row=i, column=2, value=sheet).font = Font(name="Calibri", size=11, bold=True, color=NAVY)
        ws.cell(row=i, column=2).border = ALL_BORDERS
        ws.cell(row=i, column=2).alignment = LEFT_CENTER
        ws.cell(row=i, column=3, value=desc).font = BODY_FONT
        ws.cell(row=i, column=3).border = ALL_BORDERS
        ws.cell(row=i, column=3).alignment = WRAP_TOP


# ---------------------------------------------------------------------------
# Regression / UAT / Release / Bug Tracker / Test Summary
# ---------------------------------------------------------------------------


REGRESSION_CHECKLIST = [
    "Cold start launches successfully without crash (Android + iOS)",
    "Login with valid credentials succeeds",
    "Token refresh works silently on 401",
    "Logout clears all tokens and returns to Login",
    "Dashboard shows correct aggregate balances",
    "Create Group → add member → add expense → settle (golden path)",
    "Equal/Exact/Percentage/Shares splits compute correctly",
    "Edit and Delete expense respect permission rules",
    "Receipt image uploads under 2MB after compression",
    "Push notification received and tappable (foreground/background/killed)",
    "Offline banner appears + dismisses appropriately",
    "Three responsive layouts render on phone/tablet/web",
    "All 4 permission prompts include usage descriptions",
    "Currency normalization (₹ → INR) on every write",
    "Cache invalidates after writes (Dashboard updates immediately)",
    "Activity feed reflects latest events on refresh",
    "No raw secrets in release-build logs",
    "Crashlytics receives a forced test crash",
    "App icon and launcher name correct",
    "Build version + version code match release plan",
]


def build_regression(wb: Workbook) -> None:
    ws = wb.create_sheet("23_Regression_Checklist")
    ws.sheet_view.showGridLines = False
    ws.cell(row=1, column=1, value="Regression Smoke Checklist").font = TITLE_FONT
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=5)

    intro = (
        "Tick every item before approving a release. ANY 'Fail' must be triaged and "
        "linked to a defect in '26_Bug_Tracker' before sign-off."
    )
    c = ws.cell(row=2, column=1, value=intro)
    c.font = NOTE_FONT
    c.fill = NOTE_FILL
    c.alignment = WRAP_TOP
    ws.merge_cells(start_row=2, start_column=1, end_row=2, end_column=5)
    ws.row_dimensions[2].height = 32

    headers = [("#", 6), ("Checkpoint", 70), ("Status", 14), ("Tester", 18), ("Notes", 40)]
    for col_idx, (name, width) in enumerate(headers, start=1):
        cell = ws.cell(row=4, column=col_idx, value=name)
        cell.font = HEADER_FONT
        cell.fill = HEADER_FILL
        cell.alignment = CENTER
        cell.border = ALL_BORDERS
        ws.column_dimensions[get_column_letter(col_idx)].width = width
    ws.row_dimensions[4].height = 28

    for i, item in enumerate(REGRESSION_CHECKLIST, start=1):
        row = 4 + i
        ws.cell(row=row, column=1, value=i)
        ws.cell(row=row, column=2, value=item)
        for c_idx in range(1, 6):
            cell = ws.cell(row=row, column=c_idx)
            cell.border = ALL_BORDERS
            cell.alignment = WRAP_TOP if c_idx in (2, 5) else CENTER
            cell.font = BODY_FONT
            if i % 2 == 0:
                cell.fill = ZEBRA_FILL

    dv = DataValidation(type="list", formula1='"Pass,Fail,Blocked,N/A"', allow_blank=True)
    dv.add(f"C5:C{4 + len(REGRESSION_CHECKLIST)}")
    ws.add_data_validation(dv)
    ws.freeze_panes = "A5"


def build_uat(wb: Workbook) -> None:
    ws = wb.create_sheet("24_UAT_Signoff")
    ws.sheet_view.showGridLines = False
    ws.cell(row=1, column=1, value="UAT Sign-off").font = TITLE_FONT
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=5)

    intro = ("Stakeholder sign-off for the release candidate. Each signatory confirms they "
             "have reviewed the relevant area + bug tracker before approving.")
    c = ws.cell(row=2, column=1, value=intro)
    c.font = NOTE_FONT
    c.fill = NOTE_FILL
    c.alignment = WRAP_TOP
    ws.merge_cells(start_row=2, start_column=1, end_row=2, end_column=5)
    ws.row_dimensions[2].height = 32

    headers = [("Role", 24), ("Name", 24), ("Approval", 14), ("Date", 14), ("Comments / Conditions", 60)]
    for col_idx, (name, width) in enumerate(headers, start=1):
        cell = ws.cell(row=4, column=col_idx, value=name)
        cell.font = HEADER_FONT
        cell.fill = HEADER_FILL
        cell.alignment = CENTER
        cell.border = ALL_BORDERS
        ws.column_dimensions[get_column_letter(col_idx)].width = width

    roles = [
        "QA Lead", "Engineering Lead", "Product Manager",
        "Backend Lead", "Mobile Lead", "Designer", "Business Sponsor",
    ]
    for i, role in enumerate(roles, start=1):
        row = 4 + i
        ws.cell(row=row, column=1, value=role)
        for c_idx in range(1, 6):
            cell = ws.cell(row=row, column=c_idx)
            cell.border = ALL_BORDERS
            cell.font = BODY_FONT
            cell.alignment = WRAP_TOP
            if i % 2 == 0:
                cell.fill = ZEBRA_FILL
        ws.row_dimensions[row].height = 28

    dv = DataValidation(type="list", formula1='"Approved,Approved with conditions,Rejected,Pending"', allow_blank=True)
    dv.add(f"C5:C{4 + len(roles)}")
    ws.add_data_validation(dv)


RELEASE_CHECKLIST = [
    ("Code Quality", "All Lint warnings resolved (flutter analyze / eslint)"),
    ("Code Quality", "All TODO/FIXME for this release tracked in tickets"),
    ("Tests", "Regression checklist 100% Pass"),
    ("Tests", "No Critical or Major open defects"),
    ("Tests", "No more than 3 Minor open defects, each accepted by PM"),
    ("Performance", "Cold start < 3s on target devices"),
    ("Performance", "No memory leak in 30 min usage session"),
    ("Security", "No secrets in source or release logs"),
    ("Security", "HTTPS enforced; cleartext disabled"),
    ("Security", ".env file not present on any branch (history scrubbed)"),
    ("iOS", "Privacy Manifest validated by Xcode upload check"),
    ("iOS", "App Privacy questions in App Store Connect match manifest"),
    ("iOS", "TestFlight build passes external testers smoke"),
    ("iOS", "Provisioning profile + push entitlement matched to bundle id"),
    ("Android", "Play Internal Track build installs and runs on Android 10/12/14"),
    ("Android", "Pre-launch report on Play Console — 0 crashes"),
    ("Android", "Target SDK matches Play policy (currently 34+)"),
    ("Android", "Signed with upload key + Play App Signing enrolled"),
    ("Localization", "All user-facing strings in en_IN, no $ hardcoded"),
    ("Backups & Rollback", "Database migration tested + rollback plan documented"),
    ("Monitoring", "Crashlytics dashboard accessible + alerting wired"),
    ("Comms", "Release notes drafted (user-facing + internal)"),
    ("Comms", "Support team briefed on changes"),
    ("Versioning", "version + build code bumped in pubspec.yaml"),
    ("Store Listing", "Screenshots updated for Android 13+ and iOS 17+"),
    ("Store Listing", "Privacy Policy + Terms URL reachable"),
]


def build_release_readiness(wb: Workbook) -> None:
    ws = wb.create_sheet("25_Release_Readiness")
    ws.sheet_view.showGridLines = False
    ws.cell(row=1, column=1, value="Release Readiness Checklist").font = TITLE_FONT
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=5)

    intro = "Final go / no-go check before pushing to Play Store / App Store. ALL rows must be Yes (or explicit N/A) to ship."
    c = ws.cell(row=2, column=1, value=intro)
    c.font = NOTE_FONT
    c.fill = NOTE_FILL
    c.alignment = WRAP_TOP
    ws.merge_cells(start_row=2, start_column=1, end_row=2, end_column=5)
    ws.row_dimensions[2].height = 30

    headers = [("Area", 18), ("Checkpoint", 70), ("Status", 12), ("Owner", 18), ("Notes", 40)]
    for col_idx, (name, width) in enumerate(headers, start=1):
        cell = ws.cell(row=4, column=col_idx, value=name)
        cell.font = HEADER_FONT
        cell.fill = HEADER_FILL
        cell.alignment = CENTER
        cell.border = ALL_BORDERS
        ws.column_dimensions[get_column_letter(col_idx)].width = width

    for i, (area, item) in enumerate(RELEASE_CHECKLIST, start=1):
        row = 4 + i
        ws.cell(row=row, column=1, value=area)
        ws.cell(row=row, column=2, value=item)
        for c_idx in range(1, 6):
            cell = ws.cell(row=row, column=c_idx)
            cell.border = ALL_BORDERS
            cell.font = BODY_FONT
            cell.alignment = WRAP_TOP if c_idx in (2, 5) else CENTER
            if i % 2 == 0:
                cell.fill = ZEBRA_FILL

    dv = DataValidation(type="list", formula1='"Yes,No,N/A,Pending"', allow_blank=True)
    dv.add(f"C5:C{4 + len(RELEASE_CHECKLIST)}")
    ws.add_data_validation(dv)
    ws.freeze_panes = "A5"


BUG_TRACKER_COLUMNS = [
    ("Defect ID", 12),
    ("Reported Date", 14),
    ("Reporter", 16),
    ("Title", 40),
    ("Steps to Reproduce", 55),
    ("Expected", 35),
    ("Actual", 35),
    ("Linked Test Case ID", 18),
    ("Module", 16),
    ("Platform", 12),
    ("Device / OS", 18),
    ("Build Version", 14),
    ("Severity", 12),
    ("Priority", 12),
    ("Assigned To", 16),
    ("Status", 14),
    ("Resolution", 35),
    ("Fixed In Build", 14),
    ("Verified By", 16),
    ("Closed Date", 14),
    ("Evidence Link", 28),
    ("Remarks", 30),
]


SAMPLE_DEFECTS = [
    {
        "Defect ID": "BUG_001",
        "Title": "Sign-up succeeds but OTP screen does not auto-receive SMS (Android 14)",
        "Steps to Reproduce": "1. Open Register\n2. Enter valid name + phone\n3. Tap Continue",
        "Expected": "OTP autofills via SMS Retriever",
        "Actual": "OTP screen opens but autofill never fires; manual entry works",
        "Linked Test Case ID": "TC_AUTH_19",
        "Module": "Authentication",
        "Platform": "Android",
        "Device / OS": "Pixel 6 / Android 14",
        "Build Version": "3.2.1+20",
        "Severity": "Minor",
        "Priority": "Medium",
        "Status": "Open",
    },
    {
        "Defect ID": "BUG_002",
        "Title": "Exact split allows save when sum is 0.005 off",
        "Steps to Reproduce": "1. Add Expense → Exact split\n2. Amount 1000\n3. Splits sum 999.995",
        "Expected": "Save blocked — splits must equal total",
        "Actual": "Save accepted; backend stores mismatched splits",
        "Linked Test Case ID": "TC_EXP_03",
        "Module": "Expenses",
        "Platform": "Both",
        "Device / OS": "iPhone 13 / iOS 17.5",
        "Build Version": "3.2.1+20",
        "Severity": "Major",
        "Priority": "High",
        "Status": "Open",
    },
]


def build_bug_tracker(wb: Workbook) -> None:
    ws = wb.create_sheet("26_Bug_Tracker")
    ws.sheet_view.showGridLines = False
    ws.cell(row=1, column=1, value="Defect / Bug Tracker").font = TITLE_FONT
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=10)

    intro = ("Single source of truth for defects from this release cycle. Defect IDs in this sheet "
             "are referenced from the 'Defect ID' column on every test case sheet.")
    c = ws.cell(row=2, column=1, value=intro)
    c.font = NOTE_FONT
    c.fill = NOTE_FILL
    c.alignment = WRAP_TOP
    ws.merge_cells(start_row=2, start_column=1, end_row=2, end_column=len(BUG_TRACKER_COLUMNS))
    ws.row_dimensions[2].height = 30

    header_row = 4
    for col_idx, (name, width) in enumerate(BUG_TRACKER_COLUMNS, start=1):
        cell = ws.cell(row=header_row, column=col_idx, value=name)
        cell.font = HEADER_FONT
        cell.fill = HEADER_FILL
        cell.alignment = CENTER
        cell.border = ALL_BORDERS
        ws.column_dimensions[get_column_letter(col_idx)].width = width
    ws.row_dimensions[header_row].height = 32

    for i, defect in enumerate(SAMPLE_DEFECTS, start=1):
        row = header_row + i
        for col_idx, (name, _) in enumerate(BUG_TRACKER_COLUMNS, start=1):
            cell = ws.cell(row=row, column=col_idx, value=defect.get(name, ""))
            cell.font = BODY_FONT
            cell.alignment = WRAP_TOP
            cell.border = ALL_BORDERS
            if i % 2 == 0:
                cell.fill = ZEBRA_FILL
        ws.row_dimensions[row].height = 80

    # Empty rows for ongoing logging
    for j in range(len(SAMPLE_DEFECTS) + 1, len(SAMPLE_DEFECTS) + 30):
        row = header_row + j
        for col_idx in range(1, len(BUG_TRACKER_COLUMNS) + 1):
            cell = ws.cell(row=row, column=col_idx)
            cell.border = ALL_BORDERS
            cell.font = BODY_FONT
            cell.alignment = WRAP_TOP
            if j % 2 == 0:
                cell.fill = ZEBRA_FILL

    # Validations
    last_row = header_row + len(SAMPLE_DEFECTS) + 30
    name_to_col = {n: i for i, (n, _) in enumerate(BUG_TRACKER_COLUMNS, start=1)}
    validations = {
        name_to_col["Platform"]: PLATFORM_OPTIONS,
        name_to_col["Severity"]: SEVERITY_OPTIONS,
        name_to_col["Priority"]: PRIORITY_OPTIONS,
        name_to_col["Status"]: "Open,In Progress,Fixed,Verified,Closed,Won't Fix,Duplicate",
    }
    for col_idx, formula in validations.items():
        dv = DataValidation(type="list", formula1=f'"{formula}"', allow_blank=True)
        col_letter = get_column_letter(col_idx)
        dv.add(f"{col_letter}{header_row + 1}:{col_letter}{last_row}")
        ws.add_data_validation(dv)

    ws.freeze_panes = f"E{header_row + 1}"


def build_test_summary(wb: Workbook, test_sheet_names: list[str]) -> None:
    ws = wb.create_sheet("27_Test_Summary")
    ws.sheet_view.showGridLines = False
    ws.cell(row=1, column=1, value="Live Test Summary Dashboard").font = TITLE_FONT
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=6)

    intro = ("Each row counts Status values from the Status column (column R) of each module sheet. "
             "Numbers update live as testers fill in the workbook.")
    c = ws.cell(row=2, column=1, value=intro)
    c.font = NOTE_FONT
    c.fill = NOTE_FILL
    c.alignment = WRAP_TOP
    ws.merge_cells(start_row=2, start_column=1, end_row=2, end_column=6)
    ws.row_dimensions[2].height = 32

    headers = [
        ("Module Sheet", 28),
        ("Pass", 10),
        ("Fail", 10),
        ("Blocked", 12),
        ("Not Tested", 14),
        ("Total", 10),
    ]
    for col_idx, (name, width) in enumerate(headers, start=1):
        cell = ws.cell(row=4, column=col_idx, value=name)
        cell.font = HEADER_FONT
        cell.fill = HEADER_FILL
        cell.alignment = CENTER
        cell.border = ALL_BORDERS
        ws.column_dimensions[get_column_letter(col_idx)].width = width
    ws.row_dimensions[4].height = 28

    # status column on test sheets is column R (18)
    status_col = "R"
    for i, sheet_name in enumerate(test_sheet_names, start=1):
        row = 4 + i
        # Quote sheet name for cross-sheet references
        sheet_ref = f"'{sheet_name}'!${status_col}:${status_col}"
        ws.cell(row=row, column=1, value=sheet_name)
        ws.cell(row=row, column=2, value=f"=COUNTIF({sheet_ref},\"Pass\")")
        ws.cell(row=row, column=3, value=f"=COUNTIF({sheet_ref},\"Fail\")")
        ws.cell(row=row, column=4, value=f"=COUNTIF({sheet_ref},\"Blocked\")")
        ws.cell(row=row, column=5, value=f"=COUNTIF({sheet_ref},\"Not Tested\")")
        ws.cell(row=row, column=6, value=f"=SUM(B{row}:E{row})")
        for c_idx in range(1, 7):
            cell = ws.cell(row=row, column=c_idx)
            cell.border = ALL_BORDERS
            cell.font = BODY_FONT
            cell.alignment = CENTER if c_idx > 1 else LEFT_CENTER
            if i % 2 == 0:
                cell.fill = ZEBRA_FILL

    # Totals row
    total_row = 4 + len(test_sheet_names) + 1
    ws.cell(row=total_row, column=1, value="TOTAL")
    ws.cell(row=total_row, column=1).font = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
    ws.cell(row=total_row, column=1).fill = SECTION_FILL
    for col in range(2, 7):
        letter = get_column_letter(col)
        ws.cell(row=total_row, column=col,
                value=f"=SUM({letter}5:{letter}{4 + len(test_sheet_names)})")
        ws.cell(row=total_row, column=col).font = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
        ws.cell(row=total_row, column=col).fill = SECTION_FILL
        ws.cell(row=total_row, column=col).alignment = CENTER
        ws.cell(row=total_row, column=col).border = ALL_BORDERS

    # KPI block
    kpi_row = total_row + 3
    ws.cell(row=kpi_row, column=1, value="Pass %").font = SUBTITLE_FONT
    ws.cell(row=kpi_row, column=2,
            value=f"=IFERROR(B{total_row}/F{total_row}, 0)")
    ws.cell(row=kpi_row, column=2).number_format = "0.0%"

    ws.cell(row=kpi_row + 1, column=1, value="Fail %").font = SUBTITLE_FONT
    ws.cell(row=kpi_row + 1, column=2,
            value=f"=IFERROR(C{total_row}/F{total_row}, 0)")
    ws.cell(row=kpi_row + 1, column=2).number_format = "0.0%"

    ws.cell(row=kpi_row + 2, column=1, value="Coverage %").font = SUBTITLE_FONT
    ws.cell(row=kpi_row + 2, column=2,
            value=f"=IFERROR((B{total_row}+C{total_row}+D{total_row})/F{total_row}, 0)")
    ws.cell(row=kpi_row + 2, column=2).number_format = "0.0%"

    for r in range(kpi_row, kpi_row + 3):
        ws.cell(row=r, column=2).font = Font(name="Calibri", size=14, bold=True, color=NAVY)
        ws.cell(row=r, column=2).alignment = CENTER

    ws.freeze_panes = "A5"


# ---------------------------------------------------------------------------
# Build the workbook
# ---------------------------------------------------------------------------


def build_workbook() -> Workbook:
    wb = Workbook()
    build_cover(wb)

    sheets: list[tuple[str, str, list[dict]]] = [
        ("01_Authentication",
         "Sign Up, Login (password), OTP, Forgot Password, Social Sign-in, Session, Logout.",
         auth_cases()),
        ("02_User_Profile",
         "View + edit profile, avatar upload, password change, currency preference, balance privacy.",
         profile_cases()),
        ("03_Dashboard",
         "Aggregate balances, recent activity, pull-to-refresh, empty/loading/error states, responsive layouts.",
         dashboard_cases()),
        ("04_Navigation",
         "Bottom nav, sidebar, hardware back, iOS swipe back, deep routes.",
         navigation_cases()),
        ("05_Groups",
         "Create/edit/archive/delete, member management, WhatsApp invites, role changes.",
         groups_cases()),
        ("06_Expenses",
         "Add/edit/delete, all 4 split types, receipt attachments, categories, edge cases.",
         expenses_cases()),
        ("07_Settlements",
         "Record full/partial settlements, history, undo, cross-group settlements.",
         settlements_cases()),
        ("08_Activity",
         "Feed display, type filters, unread badge, mark-as-read, deep links.",
         activity_cases()),
        ("09_Reports",
         "Charts, date ranges, PDF export, empty range handling.",
         reports_cases()),
        ("10_Friends",
         "Aggregate friend list, per-group breakdown, direct settle.",
         friends_cases()),
        ("11_API_Validation",
         "Response envelope contract, auth headers, refresh token flow, rate limits, payload limits, pagination, cache.",
         api_cases()),
        ("12_Push_Notifications",
         "Permission, FCM token registration, foreground/background/killed delivery, deep links.",
         push_cases()),
        ("13_Deep_Links",
         "WhatsApp invite link → registration → join, push deep links, invalid route handling.",
         deeplink_cases()),
        ("14_Permissions",
         "Camera, Photos, Contacts, Notifications + hygiene checks for Microphone/Location/Bluetooth.",
         permissions_cases()),
        ("15_Offline_Network",
         "Offline banner, mutation block, reconnect, slow 3G degradation, cached reads.",
         offline_cases()),
        ("16_Performance",
         "Cold/hot start, scroll performance, memory, network call efficiency.",
         performance_cases()),
        ("17_Security",
         "Token storage at rest, HTTPS enforcement, app-switcher privacy, ACL enforcement, XSS sanitization.",
         security_cases()),
        ("18_Payment",
         "Placeholder — no payment integration currently. Replace when UPI/Stripe is added.",
         payment_cases()),
        ("19_Subscription",
         "Placeholder — no subscription tier currently. Replace when Pro plans are added.",
         subscription_cases()),
        ("20_Settings",
         "Theme switcher, currency default, notification preferences, account deletion, legal links.",
         settings_cases()),
        ("21_Crash_Exception",
         "Crashlytics pipeline, graceful recovery, malformed data, low-memory, rotation.",
         crash_cases()),
        ("22_Cross_Platform",
         "Android-specific (versions, edge-to-edge, predictive back) + iOS-specific (versions, Dynamic Type, Privacy Manifest, iPad).",
         cross_platform_cases()),
    ]

    test_sheet_names: list[str] = []
    for sheet_name, intro, cases in sheets:
        make_test_sheet(wb, sheet_name, intro, cases)
        test_sheet_names.append(sheet_name)

    build_regression(wb)
    build_uat(wb)
    build_release_readiness(wb)
    build_bug_tracker(wb)
    build_test_summary(wb, test_sheet_names)

    return wb


def main() -> None:
    here = os.path.dirname(os.path.abspath(__file__))
    out_path = os.path.join(here, "KharchaSplit_QA_TestCases.xlsx")
    wb = build_workbook()
    wb.save(out_path)
    size_kb = os.path.getsize(out_path) / 1024
    total_sheets = len(wb.sheetnames)
    print(f"Wrote {out_path} ({size_kb:.1f} KB, {total_sheets} sheets)")


if __name__ == "__main__":
    main()
