use std::path::{Path, PathBuf};

#[derive(Debug)]
pub struct CodeGen {
    inputs: Vec<PathBuf>,
    output_dir: PathBuf,
    includes: Vec<PathBuf>,
}

const VERSION: &str = env!("CARGO_PKG_VERSION");

impl CodeGen {
    pub fn new() -> Self {
        Self {
            inputs: Vec::new(),
            output_dir: PathBuf::from(std::env::var("OUT_DIR").unwrap()).join("protobuf_generated"),
            includes: Vec::new(),
        }
    }

    pub fn input(&mut self, input: impl AsRef<Path>) -> &mut Self {
        self.inputs.push(input.as_ref().to_owned());
        self
    }

    pub fn inputs(&mut self, inputs: impl IntoIterator<Item = impl AsRef<Path>>) -> &mut Self {
        self.inputs.extend(inputs.into_iter().map(|input| input.as_ref().to_owned()));
        self
    }

    pub fn output_dir(&mut self, output_dir: impl AsRef<Path>) -> &mut Self {
        self.output_dir = output_dir.as_ref().to_owned();
        self
    }

    pub fn include(&mut self, include: impl AsRef<Path>) -> &mut Self {
        self.includes.push(include.as_ref().to_owned());
        self
    }

    pub fn includes(&mut self, includes: impl Iterator<Item = impl AsRef<Path>>) -> &mut Self {
        self.includes.extend(includes.into_iter().map(|include| include.as_ref().to_owned()));
        self
    }

    fn expected_generated_rs_files(&self) -> Vec<PathBuf> {
        self.inputs
            .iter()
            .map(|input| {
                let mut input = input.clone();
                assert!(input.set_extension("u.pb.rs"));
                self.output_dir.join(input)
            })
            .collect()
    }

    fn expected_generated_c_files(&self) -> Vec<PathBuf> {
        self.inputs
            .iter()
            .map(|input| {
                let mut input = input.clone();
                assert!(input.set_extension("upb_minitable.c"));
                self.output_dir.join(input)
            })
            .collect()
    }

    fn protoc_version() -> String {
        let output = std::process::Command::new("protoc").arg("--version").output().unwrap().stdout;

        // The output of protoc --version looks something like "libprotoc XX.Y", with a
        // possible suffix starting with a dash. We want to return just the
        // "XX.Y" part.
        let mut s =
            String::from_utf8(output).unwrap().strip_prefix("libprotoc ").unwrap().to_string();
        let first_dash = s.find('-');
        if let Some(i) = first_dash {
            s.truncate(i);
        }
        s
    }

    fn expected_protoc_version() -> String {
        let mut s = VERSION.to_string();
        let first_dash = s.find('-');
        if let Some(i) = first_dash {
            s.truncate(i);
        }
        let mut v: Vec<&str> = s.split('.').collect();
        assert_eq!(v.len(), 3);
        v.remove(0);
        v.join(".")
    }

    pub fn generate_and_compile(&self) -> Result<(), String> {
        let upb_version = std::env::var("DEP_UPB_VERSION").expect("DEP_UPB_VERSION should have been set, make sure that the Protobuf crate is a dependency");
        if VERSION != upb_version {
            panic!(
                "protobuf-codegen version {} does not match protobuf version {}.",
                VERSION, upb_version
            );
        }

        let protoc_version = Self::protoc_version();
        let expected_protoc_version = Self::expected_protoc_version();
        if protoc_version != expected_protoc_version {
            panic!(
                "Expected protoc version {} but found {}",
                expected_protoc_version, protoc_version
            );
        }

        let mut cmd = std::process::Command::new("protoc");
        for input in &self.inputs {
            cmd.arg(input);
        }
        if !self.output_dir.exists() {
            // Attempt to make the directory if it doesn't exist
            let _ = std::fs::create_dir(&self.output_dir);
        }

        for include in &self.includes {
            println!("cargo:rerun-if-changed={}", include.display());
        }

        cmd.arg(format!("--rust_out={}", self.output_dir.display()))
            .arg("--rust_opt=experimental-codegen=enabled,kernel=upb")
            .arg(format!("--upb_minitable_out={}", self.output_dir.display()));
        for include in &self.includes {
            cmd.arg(format!("--proto_path={}", include.display()));
        }
        let output = cmd.output().map_err(|e| format!("failed to run protoc: {}", e))?;
        println!("{}", std::str::from_utf8(&output.stdout).unwrap());
        eprintln!("{}", std::str::from_utf8(&output.stderr).unwrap());
        assert!(output.status.success());
        self.compile_only()
    }

    /// Builds and links the C code.
    pub fn compile_only(&self) -> Result<(), String> {
        let mut cc_build = cc::Build::new();
        cc_build
            .include(
                std::env::var_os("DEP_UPB_INCLUDE")
                    .expect("DEP_UPB_INCLUDE should have been set, make sure that the Protobuf crate is a dependency"),
            )
            .include(self.output_dir.clone())
            .flag("-std=c99");

        for path in &self.expected_generated_rs_files() {
            if !path.exists() {
                return Err(format!("expected generated file {} does not exist", path.display()));
            }
            println!("cargo:rerun-if-changed={}", path.display());
        }
        for path in &self.expected_generated_c_files() {
            if !path.exists() {
                return Err(format!("expected generated file {} does not exist", path.display()));
            }
            println!("cargo:rerun-if-changed={}", path.display());
            cc_build.file(path);
        }
        cc_build.compile(&format!("{}_upb_gen_code", std::env::var("CARGO_PKG_NAME").unwrap()));
        Ok(())
    }
}
