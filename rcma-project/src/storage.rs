use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, fs, path::PathBuf};

pub trait Storage {
    fn load(&mut self, path: &PathBuf) -> Result<()>;
    fn save(&self, path: &PathBuf) -> Result<()>;

    fn get(&self, name: &str) -> Option<Package>;
    fn add(&mut self, package: Package);
    fn remove(&mut self, name: &str);
}

#[derive(Debug)]
pub struct StorageManager<S: Storage + Sized> {
    path: PathBuf,
    storage: S,
}
#[derive(Debug, Clone)]
pub struct JsonStorage {
    items: Vec<Package>,
}

impl Storage for JsonStorage {
    fn load(&mut self, path: &PathBuf) -> Result<()> {
        let data = fs::read_to_string(path)?;
        self.items = serde_json::from_str(&data)?;

        Ok(())
    }
    fn save(&self, path: &PathBuf) -> Result<()> {
        let data = serde_json::to_string(&self.items)?;
        fs::write(path, data)?;
        Ok(())
    }

    fn get(&self, name: &str) -> Option<Package> {
        self.items
            .iter()
            .find(|item| match item {
                Package::Name { name: n, .. } => n == name,
                Package::NameWithDeps { name: n, .. } => n == name,
            })
            .cloned()
    }
    fn add(&mut self, package: Package) {
        self.items.push(package);
    }
    fn remove(&mut self, name: &str) {
        self.items.retain(|item| match item {
            Package::Name { name: n, .. } => n != name,
            Package::NameWithDeps { name: n, .. } => n != name,
        });
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Package {
    Name {
        name: String,
        installer: Installer,
    },
    NameWithDeps {
        name: String,
        deps: Vec<String>,
        installer: Installer,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Installer {
    Pacman,
    AUR,
}
