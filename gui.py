from PySide6.QtWidgets import (QMainWindow, QApplication, QWidget, QVBoxLayout, 
                             QHBoxLayout, QLabel, QPushButton, QSlider, QTabWidget,
                             QToolBar, QDockWidget, QGridLayout, QScrollArea, QFrame)
from PySide6.QtCore import Qt, QTimer, QSize
from PySide6.QtGui import QIcon, QAction, QColor, QPalette
import sys

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("OpenTune DAW")
        self.setGeometry(100, 100, 1400, 900)
        self.setStyleSheet("""
            QMainWindow {
                background-color: #2D2D2D;
                color: #FFFFFF;
            }
            QLabel {
                color: #FFFFFF;
            }
            QPushButton {
                background-color: #404040;
                color: #FFFFFF;
                border: none;
                padding: 5px;
                border-radius: 3px;
            }
            QPushButton:hover {
                background-color: #505050;
            }
            QDockWidget {
                color: #FFFFFF;
            }
            QDockWidget::title {
                background-color: #404040;
                padding: 5px;
            }
        """)
        
        self.setup_ui()
        
    def setup_ui(self):
        # Create Main Layout
        self.central_widget = QWidget()
        self.setCentralWidget(self.central_widget)
        self.main_layout = QVBoxLayout(self.central_widget)
        
        # Create Transport Bar
        self.create_transport_bar()
        
        # Create Main Sections
        self.create_channel_rack()
        self.create_pattern_grid()
        self.create_tracker_editor()
        self.create_piano_roll()
        self.create_mixer()
        
    def create_transport_bar(self):
        transport = QToolBar()
        self.addToolBar(Qt.ToolBarArea.TopToolBarArea, transport)
        
        # Transport Controls
        play_btn = QPushButton("▶")
        stop_btn = QPushButton("⏹")
        record_btn = QPushButton("⏺")
        bpm_label = QLabel("140 BPM")
        time_label = QLabel("00:00:00.00")
        
        for widget in [play_btn, stop_btn, record_btn, bpm_label, time_label]:
            transport.addWidget(widget)
            
    def create_channel_rack(self):
        channel_dock = QDockWidget("Channel Rack", self)
        channel_widget = QWidget()
        channel_layout = QVBoxLayout(channel_widget)
        
        # Add Sample Channels
        for i in range(10):
            channel = self.create_channel_strip(f"Channel {i+1}")
            channel_layout.addWidget(channel)
            
        scroll = QScrollArea()
        scroll.setWidget(channel_widget)
        scroll.setWidgetResizable(True)
        channel_dock.setWidget(scroll)
        self.addDockWidget(Qt.DockWidgetArea.LeftDockWidgetArea, channel_dock)
        
    def create_channel_strip(self, name):
        strip = QWidget()
        layout = QHBoxLayout(strip)
        
        # Channel Controls
        name_label = QLabel(name)
        mute_btn = QPushButton("M")
        solo_btn = QPushButton("S")
        pan_slider = QSlider(Qt.Orientation.Horizontal)
        
        mute_btn.setFixedSize(20, 20)
        solo_btn.setFixedSize(20, 20)
        pan_slider.setFixedWidth(60)
        
        for widget in [name_label, mute_btn, solo_btn, pan_slider]:
            layout.addWidget(widget)
            
        return strip
        
    def create_pattern_grid(self):
        pattern_dock = QDockWidget("Patterns", self)
        pattern_widget = QWidget()
        pattern_layout = QGridLayout(pattern_widget)
        
        # Create Pattern Buttons (4x4 Grid)
        for i in range(16):
            pattern = QPushButton(f"Pattern {i+1}")
            pattern.setFixedSize(80, 80)
            pattern_layout.addWidget(pattern, i//4, i%4)
            
        pattern_dock.setWidget(pattern_widget)
        self.addDockWidget(Qt.DockWidgetArea.TopDockWidgetArea, pattern_dock)
        
    def create_tracker_editor(self):
        editor_dock = QDockWidget("Pattern Editor", self)
        editor_widget = QWidget()
        editor_layout = QGridLayout(editor_widget)
        
        # Create Tracker Grid
        for row in range(64):
            # Row number
            row_label = QLabel(f"{row:02X}")
            row_label.setStyleSheet("color: #808080;")
            editor_layout.addWidget(row_label, row, 0)
            
            # Note columns (4 tracks)
            for col in range(4):
                cell = QFrame()
                cell.setFrameStyle(QFrame.Shape.Box)
                cell.setStyleSheet("background-color: #383838; border: 1px solid #505050;")
                cell.setFixedHeight(20)
                editor_layout.addWidget(cell, row, col+1)
                
        scroll = QScrollArea()
        scroll.setWidget(editor_widget)
        editor_dock.setWidget(scroll)
        self.addDockWidget(Qt.DockWidgetArea.RightDockWidgetArea, editor_dock)
        
    def create_piano_roll(self):
        piano_dock = QDockWidget("Piano Roll", self)
        piano_widget = QWidget()
        piano_layout = QGridLayout(piano_widget)
        
        # Create Piano Keys
        for i in range(88):
            key = QPushButton()
            key.setFixedHeight(15)
            # White/Black key coloring
            is_black = i % 12 in [1, 3, 6, 8, 10]
            key.setStyleSheet(f"background-color: {'#000000' if is_black else '#FFFFFF'};")
            piano_layout.addWidget(key, i, 0)
            
        piano_dock.setWidget(piano_widget)
        self.addDockWidget(Qt.DockWidgetArea.BottomDockWidgetArea, piano_dock)
        
    def create_mixer(self):
        mixer_dock = QDockWidget("Mixer", self)
        mixer_widget = QWidget()
        mixer_layout = QHBoxLayout(mixer_widget)
        
        # Create Mixer Channels
        for i in range(12):
            channel = self.create_mixer_channel(f"Track {i+1}")
            mixer_layout.addWidget(channel)
            
        # Master Channel
        master = self.create_mixer_channel("Master")
        master.setStyleSheet("background-color: #505050;")
        mixer_layout.addWidget(master)
        
        mixer_dock.setWidget(mixer_widget)
        self.addDockWidget(Qt.DockWidgetArea.BottomDockWidgetArea, mixer_dock)
        
    def create_mixer_channel(self, name):
        channel = QWidget()
        layout = QVBoxLayout(channel)
        
        # Channel Components
        fader = QSlider(Qt.Orientation.Vertical)
        fader.setFixedHeight(150)
        name_label = QLabel(name)
        name_label.setAlignment(Qt.AlignCenter)
        
        # Effects Slots
        fx_btn1 = QPushButton("FX 1")
        fx_btn2 = QPushButton("FX 2")
        
        for widget in [fader, fx_btn1, fx_btn2, name_label]:
            layout.addWidget(widget)
            
        return channel

def main():
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())

if __name__ == '__main__':
    main()