import json
import os
from typing import Dict, List, Optional, Union
from dataclasses import dataclass
from datetime import datetime
import shutil
from pathlib import Path
import uuid

@dataclass
class Track:
    """Track information structure"""
    id: str
    name: str
    type: str  # 'audio', 'midi', 'automation'
    is_muted: bool = False
    is_solo: bool = False
    volume: float = 1.0
    pan: float = 0.0
    clips: List[Dict] = None
    effects: List[Dict] = None
    automation: Dict = None

@dataclass
class ProjectMetadata:
    """Project metadata structure"""
    name: str
    created_at: str
    modified_at: str
    author: str
    bpm: int
    time_signature: str
    sample_rate: int
    bit_depth: int

class ProjectManager:
    def __init__(self, base_path: str = "projects"):
        """Initialize Project Manager"""
        self.base_path = Path(base_path)
        self.current_project: Optional[Dict] = None
        self.current_project_path: Optional[Path] = None
        self._ensure_base_directory()

    def _ensure_base_directory(self):
        """Ensure projects directory exists"""
        self.base_path.mkdir(parents=True, exist_ok=True)

    def create_project(self, name: str, author: str, 
                      bpm: int = 140, 
                      time_signature: str = "4/4",
                      sample_rate: int = 44100,
                      bit_depth: int = 24) -> bool:
        """Create a new project"""
        try:
            # Generate unique project ID
            project_id = str(uuid.uuid4())
            
            # Create project metadata
            metadata = ProjectMetadata(
                name=name,
                created_at=datetime.utcnow().isoformat(),
                modified_at=datetime.utcnow().isoformat(),
                author=author,
                bpm=bpm,
                time_signature=time_signature,
                sample_rate=sample_rate,
                bit_depth=bit_depth
            )

            # Create project structure
            project = {
                "id": project_id,
                "metadata": metadata.__dict__,
                "tracks": [],
                "mixer": {
                    "master": {
                        "volume": 1.0,
                        "effects": []
                    },
                    "buses": []
                },
                "patterns": [],
                "automation": {},
                "markers": []
            }

            # Create project directory
            project_dir = self.base_path / project_id
            project_dir.mkdir(parents=True, exist_ok=True)
            
            # Create subdirectories
            (project_dir / "audio").mkdir(exist_ok=True)
            (project_dir / "midi").mkdir(exist_ok=True)
            (project_dir / "bounces").mkdir(exist_ok=True)
            (project_dir / "automation").mkdir(exist_ok=True)

            # Save project file
            self._save_project_file(project, project_dir)
            
            # Set as current project
            self.current_project = project
            self.current_project_path = project_dir
            
            return True

        except Exception as e:
            print(f"Error creating project: {e}")
            return False

    def open_project(self, project_id: str) -> bool:
        """Open an existing project"""
        try:
            project_dir = self.base_path / project_id
            if not project_dir.exists():
                raise FileNotFoundError(f"Project {project_id} not found")

            # Load project file
            project_file = project_dir / "project.json"
            with open(project_file, 'r') as f:
                project = json.load(f)

            self.current_project = project
            self.current_project_path = project_dir
            return True

        except Exception as e:
            print(f"Error opening project: {e}")
            return False

    def save_project(self) -> bool:
        """Save current project"""
        if not self.current_project or not self.current_project_path:
            return False

        try:
            # Update modification time
            self.current_project["metadata"]["modified_at"] = datetime.utcnow().isoformat()
            
            # Save project file
            self._save_project_file(self.current_project, self.current_project_path)
            return True

        except Exception as e:
            print(f"Error saving project: {e}")
            return False

    def _save_project_file(self, project: Dict, project_dir: Path):
        """Save project to JSON file"""
        project_file = project_dir / "project.json"
        with open(project_file, 'w') as f:
            json.dump(project, f, indent=4)

    def add_track(self, name: str, track_type: str) -> Optional[str]:
        """Add a new track to the project"""
        if not self.current_project:
            return None

        try:
            track = Track(
                id=str(uuid.uuid4()),
                name=name,
                type=track_type,
                clips=[],
                effects=[],
                automation={}
            )
            
            self.current_project["tracks"].append(track.__dict__)
            return track.id

        except Exception as e:
            print(f"Error adding track: {e}")
            return None

    def delete_track(self, track_id: str) -> bool:
        """Delete a track from the project"""
        if not self.current_project:
            return False

        try:
            self.current_project["tracks"] = [
                track for track in self.current_project["tracks"]
                if track["id"] != track_id
            ]
            return True

        except Exception as e:
            print(f"Error deleting track: {e}")
            return False

    def update_track(self, track_id: str, **kwargs) -> bool:
        """Update track properties"""
        if not self.current_project:
            return False

        try:
            for track in self.current_project["tracks"]:
                if track["id"] == track_id:
                    track.update(kwargs)
                    return True
            return False

        except Exception as e:
            print(f"Error updating track: {e}")
            return False

    def add_marker(self, position: float, name: str, color: str = "#ffffff") -> bool:
        """Add a marker to the project"""
        if not self.current_project:
            return False

        try:
            marker = {
                "id": str(uuid.uuid4()),
                "position": position,
                "name": name,
                "color": color
            }
            self.current_project["markers"].append(marker)
            return True

        except Exception as e:
            print(f"Error adding marker: {e}")
            return False

    def backup_project(self) -> bool:
        """Create a backup of the current project"""
        if not self.current_project or not self.current_project_path:
            return False

        try:
            # Create backup directory
            backup_dir = self.base_path / "backups"
            backup_dir.mkdir(exist_ok=True)

            # Create backup with timestamp
            timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
            project_id = self.current_project["id"]
            backup_path = backup_dir / f"{project_id}_{timestamp}"

            # Copy project directory
            shutil.copytree(self.current_project_path, backup_path)
            return True

        except Exception as e:
            print(f"Error creating backup: {e}")
            return False

    def get_project_list(self) -> List[Dict]:
        """Get list of all projects"""
        projects = []
        try:
            for project_dir in self.base_path.iterdir():
                if project_dir.is_dir() and (project_dir / "project.json").exists():
                    with open(project_dir / "project.json", 'r') as f:
                        project = json.load(f)
                        projects.append({
                            "id": project["id"],
                            "name": project["metadata"]["name"],
                            "author": project["metadata"]["author"],
                            "modified_at": project["metadata"]["modified_at"]
                        })
            return projects

        except Exception as e:
            print(f"Error getting project list: {e}")
            return []

    def get_project_info(self) -> Optional[Dict]:
        """Get current project information"""
        if not self.current_project:
            return None

        return {
            "id": self.current_project["id"],
            "metadata": self.current_project["metadata"],
            "track_count": len(self.current_project["tracks"]),
            "pattern_count": len(self.current_project["patterns"]),
            "marker_count": len(self.current_project["markers"])
        }

    def export_project(self, target_path: str) -> bool:
        """Export project to a different location"""
        if not self.current_project or not self.current_project_path:
            return False

        try:
            # Create target directory
            target_dir = Path(target_path)
            target_dir.mkdir(parents=True, exist_ok=True)

            # Copy project
            shutil.copytree(self.current_project_path, target_dir, dirs_exist_ok=True)
            return True

        except Exception as e:
            print(f"Error exporting project: {e}")
            return False