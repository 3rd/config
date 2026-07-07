use std::path::Path;

pub(crate) fn policy_pattern_matches(pattern: &str, subject: &str) -> bool {
    let pattern = expand_home(pattern);
    let subject = expand_home(subject);
    if !pattern.contains('*') {
        return path_matches_exact_or_descendant(&pattern, &subject);
    }
    wildcard_match(&pattern, &subject)
}

fn path_matches_exact_or_descendant(pattern: &str, subject: &str) -> bool {
    let pattern = Path::new(pattern);
    let subject = Path::new(subject);
    subject == pattern || subject.starts_with(pattern)
}

pub(crate) fn expand_home(path: &str) -> String {
    if path == "~" {
        return std::env::var("HOME").unwrap_or_else(|_| path.into());
    }
    if let Some(rest) = path.strip_prefix("~/") {
        if let Ok(home) = std::env::var("HOME") {
            return Path::new(&home).join(rest).display().to_string();
        }
    }
    path.into()
}

fn wildcard_match(pattern: &str, subject: &str) -> bool {
    let pattern_segments: Vec<&str> = pattern.split('/').collect();
    let subject_segments: Vec<&str> = subject.split('/').collect();
    segments_match(&pattern_segments, &subject_segments)
}

// `**` matches any number of path segments; `*` matches within a single
// segment only; a fully consumed pattern also matches descendants of the match,
// mirroring the exact-or-descendant behavior of non-wildcard patterns.
fn segments_match(pattern: &[&str], subject: &[&str]) -> bool {
    match pattern.split_first() {
        None => true,
        Some((&"**", rest)) => {
            if segments_match(rest, subject) {
                return true;
            }
            match subject.split_first() {
                Some((_, subject_rest)) => segments_match(pattern, subject_rest),
                None => rest.is_empty(),
            }
        }
        Some((segment, rest)) => match subject.split_first() {
            Some((subject_segment, subject_rest)) if segment_matches(segment, subject_segment) => {
                segments_match(rest, subject_rest)
            }
            _ => false,
        },
    }
}

fn segment_matches(pattern: &str, subject: &str) -> bool {
    if !pattern.contains('*') {
        return pattern == subject;
    }
    let parts: Vec<&str> = pattern.split('*').collect();
    let Some(mut remaining) = subject.strip_prefix(parts[0]) else {
        return false;
    };
    for (index, part) in parts.iter().enumerate().skip(1) {
        if index == parts.len() - 1 {
            return remaining.ends_with(part);
        }
        if part.is_empty() {
            continue;
        }
        let Some(offset) = remaining.find(part) else {
            return false;
        };
        remaining = &remaining[offset + part.len()..];
    }
    true
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn double_star_matches_descendants_not_siblings() {
        assert!(policy_pattern_matches("/opt/cache/**", "/opt/cache/pkg"));
        assert!(policy_pattern_matches(
            "/opt/cache/**",
            "/opt/cache/pkg/inner"
        ));
        assert!(!policy_pattern_matches(
            "/opt/cache/**",
            "/opt/cacheother/x"
        ));
        assert!(!policy_pattern_matches("/opt/cache/**", "/opt/cach"));
    }

    #[test]
    fn single_star_stays_within_one_segment() {
        assert!(policy_pattern_matches(
            "/run/user/*/container.sock",
            "/run/user/1000/container.sock"
        ));
        assert!(!policy_pattern_matches(
            "/run/user/*/container.sock",
            "/run/user/1000/nested/container.sock"
        ));
    }

    #[test]
    fn trailing_literal_segment_matches_descendants() {
        assert!(policy_pattern_matches(
            "/project/*/secrets",
            "/project/app/secrets/creds.txt"
        ));
        assert!(policy_pattern_matches(
            "/project/*/secrets",
            "/project/app/secrets"
        ));
        assert!(!policy_pattern_matches(
            "/project/*/secrets",
            "/project/app/other/creds.txt"
        ));
    }

    #[test]
    fn within_segment_glob_matches_suffix_not_across_slash() {
        assert!(policy_pattern_matches("/var/log/*.log", "/var/log/app.log"));
        assert!(!policy_pattern_matches(
            "/var/log/*.log",
            "/var/log/app.txt"
        ));
        assert!(!policy_pattern_matches(
            "/var/log/*.log",
            "/var/log/sub/app.log"
        ));
    }

    #[test]
    fn non_wildcard_pattern_is_exact_or_descendant() {
        assert!(policy_pattern_matches("/etc/ssh", "/etc/ssh"));
        assert!(policy_pattern_matches("/etc/ssh", "/etc/ssh/sshd_config"));
        assert!(!policy_pattern_matches("/etc/ssh", "/etc/sshd"));
    }
}
