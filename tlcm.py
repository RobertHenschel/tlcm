import sys
import shutil
import subprocess
import platform
import json
import os
from PyQt5.QtWidgets import (QApplication, QMainWindow, QMenuBar, QMessageBox, 
                            QDialog, QVBoxLayout, QLabel, QAction, QLineEdit,
                            QComboBox, QFormLayout, QFileDialog, QPushButton,
                            QStackedWidget, QWidget, QHBoxLayout, QDialogButtonBox,
                            QGridLayout, QScrollArea, QCheckBox, QMenu)
from PyQt5.QtGui import QKeySequence, QIcon
from PyQt5.QtCore import QSettings, Qt, QSize, QPoint, QRect

class AboutDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("About TLCM")
        self.setFixedSize(400, 150)  # Set fixed size
        self.setWindowFlags(self.windowFlags() & ~Qt.WindowMaximizeButtonHint)  # Remove maximize button
        
        layout = QVBoxLayout()
        
        title = QLabel("ThinLinc Connection Manager")
        title.setAlignment(Qt.AlignCenter)
        version = QLabel("Version 0.5.0")  # Updated version number
        version.setAlignment(Qt.AlignCenter)
        copyright = QLabel("© 2025 Robert Henschel")
        copyright.setAlignment(Qt.AlignCenter)
        
        layout.addWidget(title)
        layout.addWidget(version)
        layout.addWidget(copyright)
        
        self.setLayout(layout)

class AddConnectionDialog(QDialog):
    def __init__(self, parent=None, connection_data=None):
        super().__init__(parent)
        self.setWindowTitle("Edit Connection" if connection_data else "Add Connection")
        self.setModal(True)
        self.original_name = connection_data['name'] if connection_data else None  # Store original name for edit mode
        
        layout = QFormLayout()
        
        # Name field
        self.name_edit = QLineEdit()
        layout.addRow("Name:", self.name_edit)
        
        # Server field
        self.server_edit = QLineEdit()
        layout.addRow("Server:", self.server_edit)
        
        # Username field
        self.username_edit = QLineEdit()
        layout.addRow("User Name:", self.username_edit)
        
        # Authentication type combo
        self.auth_type = QComboBox()
        self.auth_type.addItems(["Password", "SSH Key"])
        self.auth_type.currentTextChanged.connect(self.on_auth_type_changed)
        layout.addRow("Authentication:", self.auth_type)
        
        # Stacked widget for auth methods
        self.auth_stack = QStackedWidget()
        
        # Empty widget for Password
        password_widget = QWidget()
        self.auth_stack.addWidget(password_widget)
        
        # SSH Key widget
        key_widget = QWidget()
        key_layout = QHBoxLayout()
        self.key_path_edit = QLineEdit()
        self.key_path_edit.setReadOnly(True)
        browse_button = QPushButton("Browse...")
        browse_button.clicked.connect(self.browse_key)
        key_layout.addWidget(self.key_path_edit)
        key_layout.addWidget(browse_button)
        key_widget.setLayout(key_layout)
        self.auth_stack.addWidget(key_widget)
        
        layout.addRow("", self.auth_stack)
        
        # Add Auto Connect checkbox before the buttons
        self.auto_connect = QCheckBox("Auto Connect")
        self.auto_connect_row = layout.rowCount()  # Remember the row number
        layout.addRow("", self.auto_connect)
        
        # Initially hide auto-connect since Password is default
        self.auto_connect.hide()
        
        # Add OK and Cancel buttons
        button_box = QDialogButtonBox(
            QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        button_box.accepted.connect(self.accept)
        button_box.rejected.connect(self.reject)
        
        layout.addRow(button_box)
        self.setLayout(layout)
        
        # If editing, populate fields with existing data
        if connection_data:
            self.name_edit.setText(connection_data['name'])
            self.server_edit.setText(connection_data['server'])
            self.username_edit.setText(connection_data['username'])
            
            # Set auth type
            index = self.auth_type.findText(connection_data['auth_type'])
            if index >= 0:
                self.auth_type.setCurrentIndex(index)
            
            # Set auth data
            if connection_data['auth_type'] == "SSH Key":
                self.key_path_edit.setText(connection_data['auth_data'])
                self.auto_connect.setChecked(connection_data.get('auto_connect', False))

    def on_auth_type_changed(self, text):
        if text == "Password":
            self.auth_stack.setCurrentIndex(0)
            self.auto_connect.hide()
            self.auto_connect.setChecked(False)  # Uncheck when hidden
        else:
            self.auth_stack.setCurrentIndex(1)
            self.auto_connect.show()
            
    def browse_key(self):
        if platform.system() not in ['Linux', 'Darwin']:  # Darwin is MacOS
            QMessageBox.warning(self,
                "Unsupported Platform",
                "SSH key authentication is currently only supported on Linux and MacOS.")
            return
            
        file_name, _ = QFileDialog.getOpenFileName(
            self,
            "Select SSH Key",
            os.path.expanduser("~/.ssh"),  # Default SSH directory works for both Linux and MacOS
            "All Files (*)")
        if file_name:
            self.key_path_edit.setText(file_name)

    def accept(self):
        # Validate required fields
        if not self.name_edit.text().strip():
            QMessageBox.warning(self, "Validation Error", "Name is required")
            return
        if not self.server_edit.text().strip():
            QMessageBox.warning(self, "Validation Error", "Server is required")
            return
        if not self.username_edit.text().strip():
            QMessageBox.warning(self, "Validation Error", "Username is required")
            return

        # Validate SSH Key if selected
        auth_type = self.auth_type.currentText()
        if auth_type == "SSH Key" and not self.key_path_edit.text():
            QMessageBox.warning(self, "Validation Error", "SSH Key path is required")
            return

        # Create connection data
        new_name = self.name_edit.text().strip()
        connection = {
            "name": new_name,
            "server": self.server_edit.text().strip(),
            "username": self.username_edit.text().strip(),
            "auth_type": auth_type,
            "auth_data": self.key_path_edit.text() if auth_type == "SSH Key" else "",
            "auto_connect": self.auto_connect.isChecked() if auth_type == "SSH Key" else False
        }

        try:
            # Load existing connections
            connections = []
            if os.path.exists('connections.json'):
                with open('connections.json', 'r') as f:
                    connections = json.load(f)

            # Check for duplicate names only for new connections or if name changed during edit
            if self.original_name is None:  # New connection
                if any(conn['name'] == new_name for conn in connections):
                    QMessageBox.warning(self, "Validation Error", 
                                      "A connection with this name already exists")
                    return
                # Add new connection
                connections.append(connection)
            else:  # Editing existing connection
                # Only check for duplicates if name was changed
                if new_name != self.original_name:
                    if any(conn['name'] == new_name for conn in connections):
                        QMessageBox.warning(self, "Validation Error", 
                                          "A connection with this name already exists")
                        return
                # Update existing connection
                for i, conn in enumerate(connections):
                    if conn['name'] == self.original_name:
                        connections[i] = connection
                        break

            # Save back to file
            with open('connections.json', 'w') as f:
                json.dump(connections, f, indent=4)

            super().accept()

        except Exception as e:
            QMessageBox.critical(self, "Error", 
                               f"Failed to save connection:\n{str(e)}")

class ConnectionWidget(QWidget):
    def __init__(self, connection_data, parent=None):
        super().__init__(parent)
        self.connection_data = connection_data
        layout = QVBoxLayout()
        layout.setAlignment(Qt.AlignCenter)
        
        # Icon
        icon_label = QLabel()
        icon_label.setPixmap(QIcon("connection.png").pixmap(48, 48))
        icon_label.setAlignment(Qt.AlignCenter)
        
        # Name
        name_label = QLabel(connection_data['name'])
        name_label.setAlignment(Qt.AlignCenter)
        
        layout.addWidget(icon_label)
        layout.addWidget(name_label)
        self.setLayout(layout)
        
        # Make widget clickable
        self.setCursor(Qt.PointingHandCursor)
        
        # Add context menu
        self.setContextMenuPolicy(Qt.CustomContextMenu)
        self.customContextMenuRequested.connect(self.show_context_menu)
        
    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            self.launch_connection()
            
    def launch_connection(self):
        try:
            # Move platform check to the start
            if platform.system() not in ['Linux', 'Darwin']:
                QMessageBox.warning(self,
                    "Unsupported Platform",
                    "ThinLinc connections are currently only supported on Linux and MacOS.")
                return
            
            # Check if tlclient exists in PATH first
            tlclient_path = shutil.which('tlclient')
            
            # On MacOS, check common installation locations if not found in PATH
            if not tlclient_path and platform.system() == 'Darwin':
                common_paths = [
                    '/Applications/ThinLinc Client.app/Contents/MacOS/tlclient',
                    os.path.expanduser('~/Applications/ThinLinc Client.app/Contents/MacOS/tlclient')
                ]
                for path in common_paths:
                    if os.path.exists(path) and os.access(path, os.X_OK):
                        tlclient_path = path
                        break
            
            if not tlclient_path:
                msg = QMessageBox(self)
                msg.setIcon(QMessageBox.Critical)
                msg.setWindowTitle("ThinLinc Client Not Found")
                msg.setText("Could not find 'tlclient' in PATH.\n\n"
                          "Please install the ThinLinc client package.\n\n"
                          "The client package can be downloaded from:")
                msg.setInformativeText("<a href='https://www.cendio.com/thinlinc/download/'>https://www.cendio.com/thinlinc/download/</a>")
                msg.setTextFormat(Qt.RichText)
                msg.exec_()
                return
            
            # Create config file name
            config_name = f"tlclient_{self.connection_data['name'].replace(' ', '_')}.conf"
            
            # Check if config file exists
            if os.path.exists(config_name):
                # Read existing config
                with open(config_name, "r") as f:
                    config = f.read()
            else:
                # Read from template if file doesn't exist
                with open("tlclient_template.conf", "r") as f:
                    config = f.read()
            
            # Update or append settings
            settings = {
                f"LOGIN_NAME": self.connection_data['username'],
                f"SERVER_NAME": self.connection_data['server'],
                f"AUTHENTICATION_METHOD": "publickey" if self.connection_data['auth_type'] == "SSH Key" else "password"
            }
            
            if self.connection_data['auth_type'] == "SSH Key":
                settings["PRIVATE_KEY"] = self.connection_data['auth_data']
            
            # Update each setting in the config
            for key, value in settings.items():
                # Check if setting already exists
                if f"{key}=" in config:
                    # Replace existing setting
                    config = '\n'.join(
                        line if not line.startswith(f"{key}=") else f"{key}={value}"
                        for line in config.splitlines()
                    )
                else:
                    # Append new setting
                    config += f"\n{key}={value}"
            
            # Write updated config file
            with open(config_name, "w") as f:
                f.write(config)
            
            # Launch tlclient based on platform
            if platform.system() == 'Linux':
                cmd = [tlclient_path, '-C', config_name]
                if self.connection_data.get('auto_connect', False):
                    cmd.extend(['-p', '1'])
                subprocess.Popen(cmd)
            elif platform.system() == 'Darwin':
                cmd = ['open', '-n', '-a', 'ThinLinc Client', config_name]
                if self.connection_data.get('auto_connect', False):
                    cmd.extend(['--args', '-p', '1'])
                subprocess.Popen(cmd)
            else:
                raise NotImplementedError(f"Platform {platform.system()} is not supported yet")
            
        except Exception as e:
            QMessageBox.critical(None, "Connection Error",
                               f"Failed to launch connection:\n{str(e)}")

    def show_context_menu(self, position):
        menu = QMenu(self)
        edit_action = menu.addAction("Edit")
        delete_action = menu.addAction("Delete")
        action = menu.exec_(self.mapToGlobal(position))
        
        if action == edit_action:
            self.edit_connection()
        elif action == delete_action:
            self.delete_connection()
            
    def edit_connection(self):
        dialog = AddConnectionDialog(self, self.connection_data)
        if dialog.exec_() == QDialog.Accepted:
            # Update connection in connections.json
            try:
                with open('connections.json', 'r') as f:
                    connections = json.load(f)
                
                # Find and update the connection
                for i, conn in enumerate(connections):
                    if conn['name'] == self.connection_data['name']:
                        connections[i] = {
                            "name": dialog.name_edit.text().strip(),
                            "server": dialog.server_edit.text().strip(),
                            "username": dialog.username_edit.text().strip(),
                            "auth_type": dialog.auth_type.currentText(),
                            "auth_data": dialog.key_path_edit.text() if dialog.auth_type.currentText() == "SSH Key" else "",
                            "auto_connect": dialog.auto_connect.isChecked() if dialog.auth_type.currentText() == "SSH Key" else False
                        }
                        break
                
                # Save updated connections
                with open('connections.json', 'w') as f:
                    json.dump(connections, f, indent=4)
                
                # Refresh the main window's connection grid
                if isinstance(self.parent(), QWidget):
                    main_window = self.parent().window()
                    if isinstance(main_window, MainWindow):
                        main_window.load_connections()
                
            except Exception as e:
                QMessageBox.critical(self, "Error", 
                                   f"Failed to update connection:\n{str(e)}")

    def delete_connection(self):
        # Ask for confirmation
        reply = QMessageBox.question(self, "Confirm Delete",
                                   f"Are you sure you want to delete the connection '{self.connection_data['name']}'?",
                                   QMessageBox.Yes | QMessageBox.No,
                                   QMessageBox.No)
        
        if reply == QMessageBox.Yes:
            try:
                # Delete the config file if it exists
                config_name = f"tlclient_{self.connection_data['name'].replace(' ', '_')}.conf"
                if os.path.exists(config_name):
                    os.remove(config_name)
                
                # Remove from connections.json
                with open('connections.json', 'r') as f:
                    connections = json.load(f)
                
                # Filter out the connection to delete
                connections = [conn for conn in connections 
                             if conn['name'] != self.connection_data['name']]
                
                # Save updated connections
                with open('connections.json', 'w') as f:
                    json.dump(connections, f, indent=4)
                
                # Refresh the main window's connection grid
                if isinstance(self.parent(), QWidget):
                    main_window = self.parent().window()
                    if isinstance(main_window, MainWindow):
                        main_window.load_connections()
                
            except Exception as e:
                QMessageBox.critical(self, "Error", 
                                   f"Failed to delete connection:\n{str(e)}")

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("ThinLinc Connections Manager")
        
        # Create central widget with scroll area
        central_widget = QWidget()
        main_layout = QVBoxLayout()
        main_layout.setAlignment(Qt.AlignTop | Qt.AlignLeft)  # Align to top-left
        
        scroll_area = QScrollArea()
        scroll_area.setWidgetResizable(True)
        scroll_area.setHorizontalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        
        self.connections_widget = QWidget()
        self.grid_layout = QGridLayout()
        self.grid_layout.setAlignment(Qt.AlignTop | Qt.AlignLeft)  # Align grid to top-left
        self.grid_layout.setSpacing(10)  # Add some spacing between items
        self.connections_widget.setLayout(self.grid_layout)
        
        scroll_area.setWidget(self.connections_widget)
        main_layout.addWidget(scroll_area)
        
        central_widget.setLayout(main_layout)
        self.setCentralWidget(central_widget)
        
        # Initialize settings
        self.settings = QSettings('RH', 'TLCM')
        
        # Create menu bar
        menubar = self.menuBar()
        
        # Connections menu
        connections_menu = menubar.addMenu('&Connections')
        
        # Add Connection action
        add_action = QAction('&Add Connection...', self)
        add_action.setShortcut(QKeySequence('Ctrl+N'))
        add_action.triggered.connect(self.add_connection)
        
        # Add to Connections menu
        connections_menu.addAction(add_action)
        connections_menu.addSeparator()
        quit_action = connections_menu.addAction('&Quit')
        quit_action.setShortcut(QKeySequence('Ctrl+Q'))
        quit_action.triggered.connect(self.close)
        
        # Help menu
        help_menu = menubar.addMenu('&Help')  # Alt+H will open this menu
        detect_client = help_menu.addAction('&Detect ThinLinc Client')
        detect_client.triggered.connect(self.detect_client)
        help_menu.addSeparator()
        about_action = help_menu.addAction('&About')  # Alt+H, Alt+A
        about_action.triggered.connect(self.show_about)
        
        # Load existing connections
        self.load_connections()
        
        # Restore previous window geometry or use default
        self.restore_window_settings()
        
    def detect_client(self):
        if platform.system() not in ['Linux', 'Darwin']:
            QMessageBox.warning(self,
                "Unsupported Platform",
                "ThinLinc client detection is currently only supported on Linux and MacOS.")
            return
            
        client_path = shutil.which('tlclient')
        
        # On MacOS, check common installation locations if not found in PATH
        if not client_path and platform.system() == 'Darwin':
            common_paths = [
                '/Applications/ThinLinc Client.app/Contents/MacOS/tlclient',
                os.path.expanduser('~/Applications/ThinLinc Client.app/Contents/MacOS/tlclient')
            ]
            for path in common_paths:
                if os.path.exists(path) and os.access(path, os.X_OK):
                    client_path = path
                    break
        
        if not client_path:
            msg = QMessageBox(self)
            msg.setIcon(QMessageBox.Critical)
            msg.setWindowTitle("ThinLinc Client Not Found")
            msg.setText("Could not find 'tlclient' in PATH.\n\n"
                       "Please install the ThinLinc client package.\n\n"
                       "The client package can be downloaded from:")
            msg.setInformativeText("<a href='https://www.cendio.com/thinlinc/download/'>https://www.cendio.com/thinlinc/download/</a>")
            msg.setTextFormat(Qt.RichText)
            msg.exec_()
            return
        
        try:
            # On Linux, try to run tlclient --version
            if platform.system() == 'Linux':
                result = subprocess.run([client_path, '--version'], 
                                  capture_output=True, 
                                  text=True,
                                  timeout=5)
                if result.returncode == 0:
                    QMessageBox.information(self,
                        "ThinLinc Client Found",
                        f"ThinLinc client found at:\n{client_path}\n\n"
                        f"Version information:\n{result.stdout.strip()}")
                else:
                    QMessageBox.warning(self,
                        "ThinLinc Client Error",
                        f"ThinLinc client found but returned error:\n{result.stderr.strip()}")
            else:
                if platform.system() == 'Darwin':
                    QMessageBox.information(self,
                        "ThinLinc Client Found",
                        f"ThinLinc client found at:\n{client_path}\n\n")
        except subprocess.TimeoutExpired:
            QMessageBox.warning(self,
                "ThinLinc Client Error",
                "ThinLinc client check timed out.")
        except Exception as e:
            QMessageBox.critical(self,
                "ThinLinc Client Error",
                f"Error checking ThinLinc client:\n{str(e)}")
    
    def show_about(self):
        dialog = AboutDialog(self)
        dialog.exec_()
    
    def closeEvent(self, event):
        # Save window geometry before closing
        self.save_window_settings()
        super().closeEvent(event)
        
    def save_window_settings(self):
        try:
            self.settings.setValue('size', self.size())
            self.settings.setValue('pos', self.pos())
            self.settings.sync()  # Force write to storage
            
            if self.settings.status() != QSettings.NoError:
                raise Exception("Failed to save settings")
                
        except Exception as e:
            QMessageBox.warning(self,
                "Settings Warning",
                f"Failed to save window settings:\n{str(e)}\n\n"
                "Window position and size will not be remembered.")
        
    def restore_window_settings(self):
        try:
            size = self.settings.value('size')
            pos = self.settings.value('pos')
            
            # Validate settings
            if size is not None and not isinstance(size, QSize):
                raise ValueError("Invalid size value in settings")
            if pos is not None and not isinstance(pos, QPoint):
                raise ValueError("Invalid position value in settings")
            
            # Get screen geometry
            screen = QApplication.desktop().availableGeometry()
            
            if size is not None:
                # Ensure window isn't larger than screen
                size = size.boundedTo(screen.size())
                self.resize(size)
            else:
                self.setGeometry(100, 100, 800, 600)
            
            if pos is not None:
                # Ensure window is visible on screen
                if not screen.contains(QRect(pos, size or self.size())):
                    # Reset to default if window would be off-screen
                    pos = QPoint(100, 100)
                self.move(pos)
                
        except Exception as e:
            QMessageBox.warning(self,
                "Settings Warning",
                f"Failed to restore window settings:\n{str(e)}\n\n"
                "Using default window size and position.")
            self.setGeometry(100, 100, 800, 600)

    def load_connections(self):
        # Clear existing widgets from grid
        while self.grid_layout.count():
            item = self.grid_layout.takeAt(0)
            widget = item.widget()
            if widget:
                widget.deleteLater()
        
        try:
            if os.path.exists('connections.json'):
                try:
                    with open('connections.json', 'r') as f:
                        connections = json.load(f)
                    
                    # Validate that we got a list
                    if not isinstance(connections, list):
                        raise ValueError("connections.json does not contain a list")
                    
                    # Add connections to grid
                    for i, conn in enumerate(connections):
                        # Validate required fields
                        required_fields = ['name', 'server', 'username', 'auth_type']
                        missing_fields = [field for field in required_fields if field not in conn]
                        if missing_fields:
                            raise ValueError(f"Connection {i+1} is missing required fields: {', '.join(missing_fields)}")
                        
                        row = i // 4  # 4 connections per row
                        col = i % 4
                        connection_widget = ConnectionWidget(conn)
                        self.grid_layout.addWidget(connection_widget, row, col)
                
                except json.JSONDecodeError as e:
                    # Handle corrupted JSON file
                    reply = QMessageBox.critical(self, 
                        "Corrupted Configuration",
                        "The connections.json file is corrupted.\n\n"
                        "Would you like to reset it to an empty configuration?",
                        QMessageBox.Yes | QMessageBox.No)
                    
                    if reply == QMessageBox.Yes:
                        # Backup corrupted file
                        backup_name = 'connections.json.backup'
                        try:
                            os.rename('connections.json', backup_name)
                            QMessageBox.information(self,
                                "Backup Created",
                                f"The corrupted file has been backed up as '{backup_name}'")
                            # Create new empty config
                            with open('connections.json', 'w') as f:
                                json.dump([], f)
                        except Exception as backup_error:
                            QMessageBox.critical(self,
                                "Error",
                                f"Failed to create backup:\n{str(backup_error)}")
                    return
                
                except ValueError as e:
                    # Handle invalid data structure
                    QMessageBox.critical(self,
                        "Invalid Configuration",
                        f"The connections.json file contains invalid data:\n{str(e)}")
                    return
        
        except Exception as e:
            QMessageBox.critical(self, 
                "Error", 
                f"Failed to load connections:\n{str(e)}")

    def add_connection(self):
        dialog = AddConnectionDialog(self)
        if dialog.exec_() == QDialog.Accepted:
            self.load_connections()  # Refresh the grid
            QMessageBox.information(self, "Success", 
                                  "Connection added successfully!")

def main():
    app = QApplication(sys.argv)
    
    window = MainWindow()
    window.show()
    sys.exit(app.exec_())

if __name__ == '__main__':
    main() 