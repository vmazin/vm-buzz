use std::env;
use std::process::{Command, Stdio};

const DEFAULT_WSL_DISTRO: &str = "Ubuntu-24.04";
const DEFAULT_KUBECTL: &str = "/snap/bin/kubectl";
const DEFAULT_NAMESPACE: &str = "hermes";
const DEFAULT_DEPLOYMENT: &str = "hermes";
const DEFAULT_CONTAINER: &str = "hermes";
const DEFAULT_ACP_PATH: &str = "/opt/hermes/.venv/bin/hermes-acp";

#[derive(Debug, PartialEq, Eq)]
struct BridgeConfig {
    wsl_distro: String,
    kubectl: String,
    namespace: String,
    deployment: String,
    container: String,
    acp_path: String,
}

impl BridgeConfig {
    fn from_env() -> Self {
        Self {
            wsl_distro: value("VM_BUZZ_WSL_DISTRO", DEFAULT_WSL_DISTRO),
            kubectl: value("VM_BUZZ_KUBECTL", DEFAULT_KUBECTL),
            namespace: value("VM_BUZZ_HERMES_NAMESPACE", DEFAULT_NAMESPACE),
            deployment: value("VM_BUZZ_HERMES_DEPLOYMENT", DEFAULT_DEPLOYMENT),
            container: value("VM_BUZZ_HERMES_CONTAINER", DEFAULT_CONTAINER),
            acp_path: value("VM_BUZZ_HERMES_ACP_PATH", DEFAULT_ACP_PATH),
        }
    }

    fn wsl_args(&self) -> Vec<String> {
        vec![
            "-d".into(),
            self.wsl_distro.clone(),
            "--".into(),
            self.kubectl.clone(),
            "-n".into(),
            self.namespace.clone(),
            "exec".into(),
            "-i".into(),
            format!("deployment/{}", self.deployment),
            "-c".into(),
            self.container.clone(),
            "--".into(),
            "/usr/bin/env".into(),
            "HERMES_ACP_SKIP_CONFIGURED_MCP=1".into(),
            self.acp_path.clone(),
        ]
    }
}

fn value(name: &str, default: &str) -> String {
    env::var(name)
        .ok()
        .filter(|value| !value.trim().is_empty())
        .unwrap_or_else(|| default.to_string())
}

fn main() {
    let config = BridgeConfig::from_env();
    let status = Command::new("wsl.exe")
        .args(config.wsl_args())
        .stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status();

    match status {
        Ok(status) => std::process::exit(status.code().unwrap_or(1)),
        Err(error) => {
            eprintln!("failed to launch cluster Hermes ACP bridge: {error}");
            std::process::exit(1);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_args_target_the_supervised_hermes_deployment() {
        let config = BridgeConfig {
            wsl_distro: DEFAULT_WSL_DISTRO.into(),
            kubectl: DEFAULT_KUBECTL.into(),
            namespace: DEFAULT_NAMESPACE.into(),
            deployment: DEFAULT_DEPLOYMENT.into(),
            container: DEFAULT_CONTAINER.into(),
            acp_path: DEFAULT_ACP_PATH.into(),
        };

        assert_eq!(
            config.wsl_args(),
            vec![
                "-d",
                "Ubuntu-24.04",
                "--",
                "/snap/bin/kubectl",
                "-n",
                "hermes",
                "exec",
                "-i",
                "deployment/hermes",
                "-c",
                "hermes",
                "--",
                "/usr/bin/env",
                "HERMES_ACP_SKIP_CONFIGURED_MCP=1",
                "/opt/hermes/.venv/bin/hermes-acp",
            ]
        );
    }
}