use super::*;

pub(super) const MAX_PROXY_CACHED_RESPONSE_BYTES: usize = 32 * 1024 * 1024;

pub(super) fn proxy_cacheable_request(request: &ProxyRequest) -> bool {
    request.method.eq_ignore_ascii_case("GET") && request.body.is_empty()
}

pub(super) fn proxy_cacheable_response(response: &[u8]) -> bool {
    if !proxy_response_status_is(response, 200) {
        return false;
    };
    let Some(headers) = proxy_response_headers(response) else {
        return false;
    };
    for line in headers.lines().skip(1) {
        let lower = line.to_ascii_lowercase();
        if lower.starts_with("vary:") {
            return false;
        }
        if lower.starts_with("set-cookie:") {
            return false;
        }
        if lower.starts_with("cache-control:")
            && (lower.contains("no-cache")
                || lower.contains("no-store")
                || lower.contains("private"))
        {
            return false;
        }
    }
    true
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct ProxyCacheMetadata {
    pub(super) cached_at: DateTime<Utc>,
    pub(super) etag: Option<String>,
    pub(super) last_modified: Option<String>,
}

pub(super) struct ProxyCacheEntry {
    pub(super) response: Vec<u8>,
    pub(super) metadata: ProxyCacheMetadata,
}

pub(super) fn read_cached_proxy_entry(
    cache_dir: &Path,
    destination: &Destination,
) -> Option<ProxyCacheEntry> {
    let Some(metadata) = read_cached_proxy_metadata(cache_dir, destination) else {
        remove_cached_proxy_entry(cache_dir, destination);
        return None;
    };
    let response = match fs::read(proxy_cache_path(cache_dir, destination)) {
        Ok(response) => response,
        Err(_) => {
            remove_cached_proxy_entry(cache_dir, destination);
            return None;
        }
    };
    Some(ProxyCacheEntry { response, metadata })
}

pub(super) fn write_cached_proxy_response(
    cache_dir: &Path,
    destination: &Destination,
    response: &[u8],
    cached_at: DateTime<Utc>,
) {
    if response.len() > MAX_PROXY_CACHED_RESPONSE_BYTES {
        remove_cached_proxy_entry(cache_dir, destination);
        return;
    }
    if fs::create_dir_all(cache_dir).is_err() {
        return;
    }
    if fs::write(proxy_cache_path(cache_dir, destination), response).is_err() {
        return;
    }
    let metadata = ProxyCacheMetadata::from_response(response, cached_at);
    write_cached_proxy_metadata(cache_dir, destination, &metadata);
}

pub(super) fn remove_cached_proxy_entry(cache_dir: &Path, destination: &Destination) {
    let _ = fs::remove_file(proxy_cache_path(cache_dir, destination));
    let _ = fs::remove_file(proxy_cache_metadata_path(cache_dir, destination));
}

pub(super) fn prune_proxy_cache(cache_dir: &Path, cache_ttl: Duration, now: DateTime<Utc>) {
    let Ok(entries) = fs::read_dir(cache_dir) else {
        return;
    };
    for entry in entries.filter_map(Result::ok) {
        let path = entry.path();
        if path.extension().and_then(|extension| extension.to_str()) != Some("json") {
            continue;
        }
        let Some(stem) = path.file_stem().and_then(|stem| stem.to_str()) else {
            continue;
        };
        let response_path = cache_dir.join(format!("{stem}.http"));
        let remove_entry = match fs::read(&path)
            .ok()
            .and_then(|content| serde_json::from_slice::<ProxyCacheMetadata>(&content).ok())
        {
            Some(metadata) => {
                !response_path.exists()
                    || (proxy_cache_stale(&metadata, cache_ttl, now) && !metadata.has_validator())
            }
            None => true,
        };
        if remove_entry {
            let _ = fs::remove_file(&path);
            let _ = fs::remove_file(response_path);
        }
    }
}

pub(super) fn refresh_cached_proxy_metadata(
    cache_dir: &Path,
    destination: &Destination,
    existing: &ProxyCacheMetadata,
    response: &[u8],
    cached_at: DateTime<Utc>,
) {
    let mut metadata = ProxyCacheMetadata::from_response(response, cached_at);
    if metadata.etag.is_none() {
        metadata.etag = existing.etag.clone();
    }
    if metadata.last_modified.is_none() {
        metadata.last_modified = existing.last_modified.clone();
    }
    write_cached_proxy_metadata(cache_dir, destination, &metadata);
}

fn write_cached_proxy_metadata(
    cache_dir: &Path,
    destination: &Destination,
    metadata: &ProxyCacheMetadata,
) {
    let Ok(content) = serde_json::to_vec(&metadata) else {
        return;
    };
    let _ = fs::write(proxy_cache_metadata_path(cache_dir, destination), content);
}

fn read_cached_proxy_metadata(
    cache_dir: &Path,
    destination: &Destination,
) -> Option<ProxyCacheMetadata> {
    let content = fs::read(proxy_cache_metadata_path(cache_dir, destination)).ok()?;
    serde_json::from_slice(&content).ok()
}

impl ProxyCacheMetadata {
    pub(super) fn from_response(response: &[u8], cached_at: DateTime<Utc>) -> Self {
        Self {
            cached_at,
            etag: proxy_response_header(response, "etag"),
            last_modified: proxy_response_header(response, "last-modified"),
        }
    }

    pub(super) fn has_validator(&self) -> bool {
        self.etag.is_some() || self.last_modified.is_some()
    }
}

pub(super) fn proxy_cache_stale(
    metadata: &ProxyCacheMetadata,
    cache_ttl: Duration,
    now: DateTime<Utc>,
) -> bool {
    let Ok(age) = now.signed_duration_since(metadata.cached_at).to_std() else {
        return true;
    };
    age > cache_ttl
}

pub(super) fn proxy_response_status_is(response: &[u8], code: u16) -> bool {
    let Some(headers) = proxy_response_headers(response) else {
        return false;
    };
    let Some(status) = headers.lines().next() else {
        return false;
    };
    let expected = format!(" {code} ");
    (status.starts_with("HTTP/1.1 ") || status.starts_with("HTTP/1.0 "))
        && status.contains(&expected)
}

fn proxy_response_header(response: &[u8], name: &str) -> Option<String> {
    let headers = proxy_response_headers(response)?;
    for line in headers.lines().skip(1) {
        let Some((header_name, value)) = line.split_once(':') else {
            continue;
        };
        if header_name.trim().eq_ignore_ascii_case(name) {
            return Some(value.trim().to_string());
        }
    }
    None
}

fn proxy_response_headers(response: &[u8]) -> Option<&str> {
    let header_end = response
        .windows(4)
        .position(|window| window == b"\r\n\r\n")?;
    std::str::from_utf8(&response[..header_end]).ok()
}

pub(super) fn proxy_cache_path(cache_dir: &Path, destination: &Destination) -> PathBuf {
    cache_dir.join(format!("{}.http", proxy_cache_key(destination)))
}

fn proxy_cache_metadata_path(cache_dir: &Path, destination: &Destination) -> PathBuf {
    cache_dir.join(format!("{}.json", proxy_cache_key(destination)))
}

fn proxy_cache_key(destination: &Destination) -> String {
    let mut hasher = Sha256::new();
    hasher.update(destination.scheme.as_bytes());
    hasher.update(b"\0");
    hasher.update(destination.host.to_ascii_lowercase().as_bytes());
    hasher.update(b"\0");
    hasher.update(destination.port.to_string().as_bytes());
    hasher.update(b"\0");
    hasher.update(destination.path.as_bytes());
    format!("{:x}", hasher.finalize())
}

#[cfg(test)]
pub(super) fn read_cached_proxy_response(
    cache_dir: &Path,
    destination: &Destination,
    cache_ttl: Duration,
    now: DateTime<Utc>,
) -> Option<Vec<u8>> {
    let entry = read_cached_proxy_entry(cache_dir, destination)?;
    if proxy_cache_stale(&entry.metadata, cache_ttl, now) {
        remove_cached_proxy_entry(cache_dir, destination);
        return None;
    }
    Some(entry.response)
}
