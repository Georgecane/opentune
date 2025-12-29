// pmanager.rs

/* Plugin Manager Implementation */

#![allow(warnings)]

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use once_cell::sync::Lazy;
use walkdir::WalkDir;

use crate::dspengine::AudioNode;
use crate::dspapi::NodeId;

pub static PMANAGER: Lazy<Arc<Mutex<PluginManager>>> = Lazy::new(|| {
    Arc::new(Mutex::new(PluginManager::new()))
});

#[derive(Debug, Clone, Copy)]
pub enum PluginFormat {
    Vst3,
    Clap,
    Lv2,
    Internal,
}

// Fixed: Added Clone derivation here
#[derive(Debug, Clone)]
pub struct PluginMetadata {
    pub name: String,
    pub path: PathBuf,
    pub format: PluginFormat,
}

type NodeCreator = Box<dyn Fn() -> Box<dyn AudioNode> + Send + Sync>;

pub struct PluginManager {
    pub registry: HashMap<String, NodeCreator>,
    pub discovered_plugins: HashMap<String, PluginMetadata>,
    next_node_id: NodeId,
}

impl PluginManager {
    pub fn new() -> Self {
        let mut manager = Self {
            registry: HashMap::new(),
            discovered_plugins: HashMap::new(),
            next_node_id: 1000,
        };
        manager.scan_standard_paths();
        manager
    }

    pub fn register<F>(&mut self, name: &str, creator: F)
    where
        F: Fn() -> Box<dyn AudioNode> + Send + Sync + 'static,
    {
        self.registry.insert(name.to_string(), Box::new(creator));
    }

    pub fn scan_standard_paths(&mut self) {
        let paths = if cfg!(target_os = "windows") {
            vec![
                "C:\\Program Files\\Common Files\\VST3",
                "C:\\Program Files\\Common Files\\CLAP",
            ]
        } else if cfg!(target_os = "linux") {
            vec![
                "/usr/lib/vst3",
                "/usr/lib/clap",
                "/usr/lib/lv2",
            ]
        } else {
            vec!["/Library/Audio/Plug-Ins/Components"]
        };

        for path in paths {
            if Path::new(path).exists() {
                self.scan_directory(path);
            }
        }
    }

    fn scan_directory(&mut self, dir: &str) {
        for entry in WalkDir::new(dir).max_depth(3).into_iter().filter_map(|e| e.ok()) {
            let path = entry.path();
            let ext = path.extension().and_then(|s| s.to_str()).unwrap_or("");

            let format = match ext {
                "vst3" => Some(PluginFormat::Vst3),
                "clap" => Some(PluginFormat::Clap),
                "lv2" => Some(PluginFormat::Lv2),
                _ => None,
            };

            if let Some(fmt) = format {
                let name = path.file_stem().unwrap().to_str().unwrap().to_string();
                self.discovered_plugins.insert(name.clone(), PluginMetadata {
                    name,
                    path: path.to_path_buf(),
                    format: fmt,
                });
            }
        }
    }

    // This is the method the engine calls
    pub fn create_node(&mut self, name: &str) -> Option<Box<dyn AudioNode>> {
        if let Some(creator) = self.registry.get(name) {
            return Some(creator());
        }

        if let Some(meta) = self.discovered_plugins.get(name).cloned() {
            return self.load_external_plugin(meta);
        }

        None
    }

    fn load_external_plugin(&self, meta: PluginMetadata) -> Option<Box<dyn AudioNode>> {
        match meta.format {
            PluginFormat::Vst3 => {
                println!("[PManager] Loading VST3: {:?}", meta.path);
                None
            }
            PluginFormat::Clap => {
                println!("[PManager] Loading CLAP: {:?}", meta.path);
                None
            }
            _ => None,
        }
    }

    pub fn generate_id(&mut self) -> NodeId {
        let id = self.next_node_id;
        self.next_node_id += 1;
        id
    }
}