mod commands;
mod inquirer;
mod storage;

use anyhow::Result;
use clap::Parser;

fn main() -> Result<()> {
    let mut args = commands::RcmaArgs::parse();
    args.path_exist_or_permission_to_create()?;

    println!("{}", args.get_path());

    Ok(())
}
