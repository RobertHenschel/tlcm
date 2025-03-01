import sys
from PyQt5.QtWidgets import (QApplication, QMainWindow, QMenuBar, QMessageBox, 
                            QDialog, QVBoxLayout, QLabel)
from PyQt5.QtGui import QKeySequence
from PyQt5.QtCore import QSettings, Qt

class AboutDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("About TLCM")
        self.setFixedSize(400, 150)  # Set fixed size
        self.setWindowFlags(self.windowFlags() & ~Qt.WindowMaximizeButtonHint)  # Remove maximize button
        
        layout = QVBoxLayout()
        
        title = QLabel("ThinLinc Connection Manager")
        title.setAlignment(Qt.AlignCenter)
        version = QLabel("Version 0.1")
        version.setAlignment(Qt.AlignCenter)
        copyright = QLabel("© 2025 Robert Henschel")
        copyright.setAlignment(Qt.AlignCenter)
        
        layout.addWidget(title)
        layout.addWidget(version)
        layout.addWidget(copyright)
        
        self.setLayout(layout)

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("ThinLinc Connections Manager")
        
        # Initialize settings
        self.settings = QSettings('RH', 'TLCM')
        
        # Create menu bar
        menubar = self.menuBar()
        
        # Connections menu
        connections_menu = menubar.addMenu('&Connections')  # Alt+C will open this menu
        quit_action = connections_menu.addAction('&Quit')  # Alt+C, Alt+Q
        quit_action.setShortcut(QKeySequence('Ctrl+Q'))
        quit_action.triggered.connect(self.close)
        
        # Help menu
        help_menu = menubar.addMenu('&Help')  # Alt+H will open this menu
        about_action = help_menu.addAction('&About')  # Alt+H, Alt+A
        about_action.triggered.connect(self.show_about)
        
        # Restore previous window geometry or use default
        self.restore_window_settings()
        
    def show_about(self):
        dialog = AboutDialog(self)
        dialog.exec_()
    
    def closeEvent(self, event):
        # Save window geometry before closing
        self.save_window_settings()
        super().closeEvent(event)
        
    def save_window_settings(self):
        self.settings.setValue('size', self.size())
        self.settings.setValue('pos', self.pos())
        
    def restore_window_settings(self):
        size = self.settings.value('size')
        pos = self.settings.value('pos')
        
        if size is not None:
            self.resize(size)
        else:
            self.setGeometry(100, 100, 800, 600)
            
        if pos is not None:
            self.move(pos)

def main():
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec_())

if __name__ == '__main__':
    main() 