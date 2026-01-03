use std::io;

pub fn question_yes_no(question: &str) -> io::Result<bool> {
    let mut ans = String::new();
    println!("{} (y/n)", question);
    std::io::stdin().read_line(&mut ans)?;
    Ok(ans.trim().to_lowercase() == "y")
}

pub fn question_string(question: &str) -> io::Result<String> {
    let mut ans = String::new();
    println!("{}", question);
    std::io::stdin().read_line(&mut ans)?;
    Ok(ans.trim().to_string())
}
