use std::{fs, io, path::Path, process};

use anyhow::Result;
use clap::{Parser, Subcommand, ValueEnum};

fn is_available_command(command: &str) -> bool {
    // if command -v "command" 1>/dev/null 2>&1; then return 0; fi
    process::Command::new(command).status().is_ok()
}

const SAVES_NAME: &str = "packages.json";
const DEFAULT_PATH_TO_SAVE: &str = "/home/nimirus/Downloads/Git/letup/rcma-saves";
lazy_static::lazy_static! {
    static ref AUR_HELPER: Option<String> = if is_available_command("yay") {
        Some(String::from("yay"))
    } else if is_available_command("paru") {
        Some(String::from("paru"))
    } else {
        None
    };
}

#[derive(Debug, Parser)]
pub struct RcmaArgs {
    #[clap(short = 's', long = "saves", default_value = DEFAULT_PATH_TO_SAVE)]
    path_to_save: String,
    #[clap(short, long)]
    aur: bool,
    #[clap(short, long)]
    pacman: bool,
}

#[derive(Debug, Clone)]
pub enum SaveType {
    Aur,
    Pamcan,
    Both,
}

impl RcmaArgs {
    fn save_type(&self) -> Option<SaveType> {
        match (self.aur, self.pacman) {
            (true, true) => Some(SaveType::Both),
            (true, false) => Some(SaveType::Aur),
            (false, true) => Some(SaveType::Pamcan),
            _ => None,
        }
    }
    pub fn path_exist_or_permission_to_create(&mut self) -> Result<()> {
        let path_to_save = self.path_to_save.clone();
        let path = Path::new(&path_to_save);
        if !path.exists() {
            println!("Path does not exist, do you want to create it? (y/n)");
            let mut ans = String::new();
            io::stdin().read_line(&mut ans)?;

            if ans.trim().to_lowercase() == "y" {
                fs::create_dir_all(&path_to_save)?;
            } else {
                println!("Enter a valid path: ");
                let mut new_path = String::new();
                io::stdin().read_line(&mut new_path)?;
                self.path_to_save = new_path.trim().to_string();

                if !Path::new(&new_path).exists() {
                    panic!("Path does not exist. Bruh");
                }
            }
        }
        Ok(())
    }

    pub fn get_path(&self) -> &str {
        &self.path_to_save
    }
}
