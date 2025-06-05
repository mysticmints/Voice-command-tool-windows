import keyboard
import speech_recognition as sr
import os
import webbrowser
import getpass
import tkinter as tk
from tkinter import filedialog, messagebox
import json
import hashlib
import threading  
import subprocess  
from pystray import Icon, MenuItem, Menu
from PIL import Image

# Store the commands file in a writable location
COMMANDS_FILE = os.path.join(os.getenv("APPDATA"), "commands.json")
hotkey = "9"  # Default hotkey, user can change this dynamically

SAFE_COMMANDS = ["notepad.exe", "calc.exe", "explorer.exe"]

# --- Safe Command Loading ---
def load_commands():
    """Load existing voice commands safely."""
    if not os.path.exists(COMMANDS_FILE):
        return {}
    try:
        with open(COMMANDS_FILE, "r") as file:
            commands = json.load(file)
            if not isinstance(commands, dict):
                raise ValueError("Invalid format in commands.json.")
            return commands
    except json.JSONDecodeError:
        return {}

# --- Saving Commands ---
def save_command():
    """Save new voice command and associated action."""
    command = command_entry.get().strip().lower()
    action = action_entry.get().strip()
    if not command or not action:
        status_label.config(text=" Please enter both a command and an action.")
        return
    
    commands = load_commands()
    commands[command] = action

    try:
        with open(COMMANDS_FILE, "w") as file:
            json.dump(commands, file, indent=4)
        status_label.config(text=" Command saved successfully!", fg="green")
        update_command_list()
    except Exception as e:
        status_label.config(text=f" Error saving command: {e}", fg="red")

# --- Deleting Commands ---
def delete_selected_command(event):
    """Deletes the selected command from the list."""
    selected_index = command_listbox.curselection()
    if not selected_index:
        return

    selected_text = command_listbox.get(selected_index[0])
    command_to_delete = selected_text.split(" → ")[0]

    commands = load_commands()
    if command_to_delete in commands:
        del commands[command_to_delete]

        try:
            with open(COMMANDS_FILE, "w") as file:
                json.dump(commands, file, indent=4)
            update_command_list()
            status_label.config(text=f" Deleted '{command_to_delete}'", fg="green")
        except Exception as e:
            status_label.config(text=f" Error deleting command: {e}", fg="red")

# --- UI Refresh ---
def update_command_list():
    """Update the listbox with saved commands."""
    command_listbox.delete(0, tk.END)
    commands = load_commands()
    for cmd, act in commands.items():
        command_listbox.insert(tk.END, f"{cmd} → {act}")

# --- Voice Command Recognition ---
def listen_for_command():
    recognizer = sr.Recognizer()
    with sr.Microphone() as source:
        print("Listening for command...")
        recognizer.adjust_for_ambient_noise(source)
        audio = recognizer.listen(source)

        try:
            command = recognizer.recognize_google(audio).lower()
            print(f" You said: {command}")
            execute_task(command)
        except sr.UnknownValueError:
            print("Could not understand the command.")
        except sr.RequestError:
            print("API unavailable.")

# --- Task Execution ---
def execute_task(command):
    """Executes recognized voice commands without file restrictions."""
    commands = load_commands()
    if command in commands:
        action = commands[command]
        
        # Allow execution of all files without restricting types
        subprocess.run(action, shell=True)
        print(f" Executing: {action}")
    else:
        print("Command not recognized.")

# --- Hotkey Customization ---
def update_hotkey():
    """Updates the listening hotkey dynamically."""
    global hotkey
    new_hotkey = hotkey_entry.get().strip()

    if new_hotkey:
        keyboard.remove_hotkey(hotkey)  # Remove the old hotkey
        hotkey = new_hotkey
        keyboard.add_hotkey(hotkey, listen_for_command)
        status_label.config(text=f"Hotkey updated to '{hotkey}'", fg="green")
    else:
        status_label.config(text="Please enter a valid hotkey.", fg="red")

# --- Minimize to System Tray (Non-blocking) ---
def minimize_to_tray():
    """Minimizes the app to system tray asynchronously."""
    root.withdraw()
    
    def tray_thread():
        icon.run()
    
    icon = Icon("Voice Command Manager", Image.new('RGB', (64, 64), (255, 255, 255)), menu=Menu(
        MenuItem("Restore", restore_window),
        MenuItem("Exit", exit_app)
    ))

    threading.Thread(target=tray_thread, daemon=True).start()  # Non-blocking tray execution

def restore_window(icon, item):
    """Restores the app window from tray."""
    icon.stop()
    root.deiconify()

def exit_app(icon, item):
    """Fully exits the application."""
    icon.stop()
    root.quit()

# --- UI Setup ---
root = tk.Tk()
root.title("🔹 Voice Command Manager")

frame = tk.Frame(root, padx=10, pady=10)
frame.pack()

tk.Label(frame, text="🔹 Enter Voice Command:").grid(row=0, column=0, pady=5, sticky="w")
command_entry = tk.Entry(frame, width=50)
command_entry.grid(row=0, column=1, pady=5)

tk.Label(frame, text="🔹 Attach Action or File:").grid(row=1, column=0, pady=5, sticky="w")
action_entry = tk.Entry(frame, width=50)
action_entry.grid(row=1, column=1, pady=5)

browse_button = tk.Button(frame, text="📂 Browse File", command=lambda: action_entry.insert(0, filedialog.askopenfilename()))
browse_button.grid(row=2, column=1, pady=5, sticky="w")

save_button = tk.Button(frame, text="💾 Save Command", command=save_command, bg="lightgreen")
save_button.grid(row=3, column=1, pady=5, sticky="w")

status_label = tk.Label(frame, text="", fg="green")
status_label.grid(row=4, columnspan=2, pady=5)

tk.Label(frame, text="🔹 Set Hotkey for Voice Activation:").grid(row=5, column=0, pady=5, sticky="w")
hotkey_entry = tk.Entry(frame, width=15)
hotkey_entry.grid(row=5, column=1, pady=5)

set_hotkey_button = tk.Button(frame, text=" Update Hotkey", command=update_hotkey, bg="lightblue")
set_hotkey_button.grid(row=6, column=1, pady=5, sticky="w")

command_listbox = tk.Listbox(frame, width=60, height=10)
command_listbox.grid(row=7, columnspan=2, pady=5)

delete_instruction_label = tk.Label(frame, text="🖱️ Right-click a command to delete it", fg="gray")
delete_instruction_label.grid(row=8, columnspan=2, pady=5)

update_command_list()

command_listbox.bind("<Button-3>", delete_selected_command)  # Right-click to delete

keyboard.add_hotkey(hotkey, listen_for_command)
print(f"🔹 Press '{hotkey}' to activate voice command listening.")

root.protocol("WM_DELETE_WINDOW", minimize_to_tray)

root.mainloop()
