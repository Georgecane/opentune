import sys
from PyQt5.QtWidgets import (QMainWindow, QApplication, QWidget, QVBoxLayout, 
                           QHBoxLayout, QLabel, QPushButton, QSlider, QDockWidget,
                           QFrame, QScrollArea, QGridLayout, QSpacerItem, QSizePolicy,
                           QMenuBar, QMenu, QAction, QToolBar, QFontComboBox, QSpinBox)
from PyQt5.QtCore import Qt, QTimer, QSize
from PyQt5.QtGui import QColor, QPalette, QFont, QIcon

class StyleSheet:
    """Centralized stylesheet for the application"""
    MAIN = """
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
            min-width: 80px;
        }
        QPushButton:hover {
            background-color: #505050;
        }
        QPushButton:pressed {
            background-color: #606060;
        }
        QDockWidget {
            color: #FFFFFF;
            border: 1px solid #404040;
        }
        QDockWidget::title {
            background: #404040;
            padding: 6px;
        }
        QSlider::groove:vertical {
            background: #404040;
            width: 4px;
        }
        QSlider::handle:vertical {
            background: #808080;
            height: 10px;
            margin: 0 -8px;
            border-radius: 5px;
        }
        QMenuBar {
            background-color: #2D2D2D;
            color: #FFFFFF;
        }
        QMenuBar::item:selected {
            background-color: #404040;
        }
        QMenu {
            background-color: #2D2D2D;
            color: #FFFFFF;
        }
        QMenu::item:selected {
            background-color: #404040;
        }
    """

class TransportBar(QToolBar):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setStyleSheet("QToolBar { background-color: #383838; border: none; }")
        self.setup_ui()

    def setup_ui(self):
        # Transport Controls
        self.play_btn = QPushButton("▶")
        self.stop_btn = QPushButton("⏹")
        self.record_btn = QPushButton("⏺")
        self.record_btn.setStyleSheet("QPushButton { color: #FF4444; }")
        
        # BPM Controls
        self.bpm_label = QLabel("BPM:")
        self.bpm_spin = QSpinBox()
        self.bpm_spin.setRange(20, 999)
        self.bpm_spin.setValue(140)
        self.bpm_spin.setStyleSheet("QSpinBox { color: white; background-color: #404040; }")
        
        # Time Display
        self.time_display = QLabel("00:00:00.00")
        self.time_display.setStyleSheet("QLabel { font-family: monospace; font-size: 14px; }")
        
        # Add widgets to toolbar
        for widget in [self.play_btn, self.stop_btn, self.record_btn, 
                      self.bpm_label, self.bpm_spin, self.time_display]:
            self.addWidget(widget)

class ChannelRack(QDockWidget):
    def __init__(self, parent=None):
        super().__init__("Channel Rack", parent)
        self.setup_ui()

    def setup_ui(self):
        # Main widget
        content = QWidget()
        layout = QVBoxLayout(content)
        
        # Add Channel Button
        add_channel_btn = QPushButton("+ Add Channel")
        layout.addWidget(add_channel_btn)
        
        # Channels Container
        channels_widget = QWidget()
        channels_layout = QVBoxLayout(channels_widget)
        
        # Add some default channels
        for i in range(8):
            channel = self.create_channel(f"Channel {i+1}")
            channels_layout.addWidget(channel)
            
        # Scroll Area
        scroll = QScrollArea()
        scroll.setWidget(channels_widget)
        scroll.setWidgetResizable(True)
        layout.addWidget(scroll)
        
        self.setWidget(content)

    def create_channel(self, name):
        channel = QFrame()
        channel.setFrameStyle(QFrame.StyledPanel)
        channel.setStyleSheet("QFrame { background-color: #383838; margin: 2px; }")
        
        layout = QHBoxLayout(channel)
        
        name_label = QLabel(name)
        mute_btn = QPushButton("M")
        solo_btn = QPushButton("S")
        volume_slider = QSlider(Qt.Horizontal)
        
        mute_btn.setFixedWidth(30)
        solo_btn.setFixedWidth(30)
        volume_slider.setFixedWidth(100)
        
        layout.addWidget(name_label)
        layout.addWidget(mute_btn)
        layout.addWidget(solo_btn)
        layout.addWidget(volume_slider)
        
        return channel

class PatternEditor(QDockWidget):
    def __init__(self, parent=None):
        super().__init__("Pattern Editor", parent)
        self.setup_ui()

    def setup_ui(self):
        content = QWidget()
        layout = QGridLayout(content)
        
        # Create header row
        for i in range(16):
            label = QLabel(f"{i+1}")
            label.setAlignment(Qt.AlignCenter)
            layout.addWidget(label, 0, i+1)
            
        # Create pattern rows
        for row in range(32):
            # Row number
            row_label = QLabel(f"{row+1:02d}")
            layout.addWidget(row_label, row+1, 0)
            
            # Note cells
            for col in range(16):
                cell = QFrame()
                cell.setFrameStyle(QFrame.StyledPanel)
                cell.setStyleSheet("QFrame { background-color: #383838; }")
                cell.setFixedHeight(20)
                layout.addWidget(cell, row+1, col+1)
        
        self.setWidget(content)

class PianoRoll(QDockWidget):
    def __init__(self, parent=None):
        super().__init__("Piano Roll", parent)
        self.setup_ui()

    def setup_ui(self):
        content = QWidget()
        layout = QHBoxLayout(content)
        
        # Piano Keys
        keys_widget = QWidget()
        keys_layout = QVBoxLayout(keys_widget)
        keys_layout.setSpacing(1)
        
        for i in range(88, 0, -1):
            key = QPushButton()
            is_black = i % 12 in [1, 3, 6, 8, 10]
            key.setStyleSheet(f"background-color: {'black' if is_black else 'white'}; \
                              color: {'white' if is_black else 'black'}")
            key.setFixedHeight(20)
            keys_layout.addWidget(key)
            
        layout.addWidget(keys_widget)
        
        # Grid area
        grid = QFrame()
        grid.setStyleSheet("QFrame { background-color: #383838; }")
        layout.addWidget(grid)
        
        self.setWidget(content)

class Mixer(QDockWidget):
    def __init__(self, parent=None):
        super().__init__("Mixer", parent)
        self.setup_ui()

    def setup_ui(self):
        content = QWidget()
        layout = QHBoxLayout(content)
        
        # Create regular channels
        for i in range(12):
            channel = self.create_mixer_channel(f"Track {i+1}")
            layout.addWidget(channel)
            
        # Create master channel
        master = self.create_mixer_channel("Master", is_master=True)
        layout.addWidget(master)
        
        self.setWidget(content)

    def create_mixer_channel(self, name, is_master=False):
        channel = QWidget()
        layout = QVBoxLayout(channel)
        
        # Volume fader
        fader = QSlider(Qt.Vertical)
        fader.setFixedHeight(200)
        
        # FX Buttons
        fx1 = QPushButton("FX 1")
        fx2 = QPushButton("FX 2")
        
        # Channel label
        label = QLabel(name)
        label.setAlignment(Qt.AlignCenter)
        
        layout.addWidget(fader)
        layout.addWidget(fx1)
        layout.addWidget(fx2)
        layout.addWidget(label)
        
        if is_master:
            channel.setStyleSheet("background-color: #505050;")
        
        return channel

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("OpenTune DAW")
        self.setGeometry(100, 100, 1400, 900)
        self.setStyleSheet(StyleSheet.MAIN)
        
        self.setup_ui()

    def setup_ui(self):
        # Create Menu Bar
        self.create_menu_bar()
        
        # Create Transport Bar
        self.transport_bar = TransportBar(self)
        self.addToolBar(self.transport_bar)
        
        # Create Central Widget
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        # Create Dock Widgets
        self.channel_rack = ChannelRack(self)
        self.pattern_editor = PatternEditor(self)
        self.piano_roll = PianoRoll(self)
        self.mixer = Mixer(self)
        
        # Add dock widgets
        self.addDockWidget(Qt.LeftDockWidgetArea, self.channel_rack)
        self.addDockWidget(Qt.RightDockWidgetArea, self.pattern_editor)
        self.addDockWidget(Qt.BottomDockWidgetArea, self.piano_roll)
        self.addDockWidget(Qt.BottomDockWidgetArea, self.mixer)

    def create_menu_bar(self):
        menubar = self.menuBar()
        
        # File Menu
        file_menu = menubar.addMenu("File")
        new_action = QAction("New Project", self)
        open_action = QAction("Open Project", self)
        save_action = QAction("Save Project", self)
        file_menu.addActions([new_action, open_action, save_action])
        
        # Edit Menu
        edit_menu = menubar.addMenu("Edit")
        undo_action = QAction("Undo", self)
        redo_action = QAction("Redo", self)
        edit_menu.addActions([undo_action, redo_action])
        
        # View Menu
        view_menu = menubar.addMenu("View")
        
        # Tools Menu
        tools_menu = menubar.addMenu("Tools")
        
        # Help Menu
        help_menu = menubar.addMenu("Help")

def main():
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec_())

if __name__ == '__main__':
    main()