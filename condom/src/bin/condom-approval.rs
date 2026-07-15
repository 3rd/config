use std::{
    cell::RefCell,
    ffi::CString,
    path::{Path, PathBuf},
    rc::Rc,
};

use anyhow::{bail, Context, Result};
use clap::{Parser, ValueEnum};
use condom::auth::prompt::{
    ApprovalPromptRequest, ApprovalPromptResponse, FilesystemAccessMode, PromptDecision,
    PromptResult,
};
use fltk::{
    app,
    browser::HoldBrowser,
    button::Button,
    enums::{Align, Color, Event, Font, FrameType, Key},
    frame::Frame,
    prelude::*,
    text::{TextBuffer, TextDisplay, WrapMode},
    window::Window,
};

#[derive(Debug, Parser)]
#[command(
    name = "condom-approval",
    version,
    about = "Show a host-side condom approval prompt"
)]
struct ApprovalCli {
    /// Probe whether the GUI backend can open the current display and exit.
    #[arg(long, hide = true)]
    probe_display: bool,
    /// Versioned JSON prompt request from condom.
    #[arg(long)]
    request_json: Option<String>,
    /// Encoded prompt payload to render.
    #[arg(long)]
    message: Option<String>,
    /// Open a representative prompt shape with sample data for UI iteration,
    /// instead of rendering a real payload.
    #[arg(long, value_enum)]
    demo: Option<DemoShape>,
}

#[derive(Clone, Copy, Debug, ValueEnum)]
enum DemoShape {
    /// Basic approval (proxy destination): no path scope or access controls.
    Proxy,
    /// Path approval: filesystem path-scope selector, no access-mode buttons.
    Path,
    /// Filesystem approval defaulting to read access.
    FsRead,
    /// Filesystem approval defaulting to write access.
    FsWrite,
    /// Filesystem approval defaulting to read + write access.
    FsReadWrite,
}

fn demo_message(shape: DemoShape) -> String {
    match shape {
        DemoShape::Proxy => "condom blocked a proxy destination:
  destination: registry.example.test:443
  app: npm
  project: /home/dev/acme-web
  command: npm install lodash"
            .into(),
        DemoShape::Path => "condom blocked filesystem access:
  path: /home/dev/acme-web/.git/config
  app: git
  project: /home/dev/acme-web
  command: git status"
            .into(),
        DemoShape::FsRead => filesystem_demo_message(
            "read",
            "/home/dev/acme-web/.env.production",
            "node",
            "node server.js",
        ),
        DemoShape::FsWrite => filesystem_demo_message(
            "write",
            "/home/dev/acme-web/dist/bundle.js",
            "esbuild",
            "esbuild --outfile=dist/bundle.js",
        ),
        DemoShape::FsReadWrite => filesystem_demo_message(
            "read-write",
            "/home/dev/acme-web/.cache/store.db",
            "vitest",
            "vitest run",
        ),
    }
}

fn filesystem_demo_message(action: &str, path: &str, app: &str, command: &str) -> String {
    format!(
        "condom blocked filesystem access:
  action: {action}
  path: {path}
  app: {app}
  project: /home/dev/acme-web
  command: {command}"
    )
}

#[derive(Clone, Debug)]
struct PromptDetails {
    title: String,
    fields: Vec<(String, String)>,
    body: Vec<String>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum RuleAction {
    Allow,
    Deny,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum RuleScope {
    Once,
    Instance,
    AppProject,
    Project,
}

#[derive(Clone, Debug)]
struct RuleSelection {
    action: RuleAction,
    scope: RuleScope,
    subject: Option<String>,
    filesystem_access: Option<FilesystemAccessMode>,
    persistent_scope_allowed: bool,
}

#[derive(Clone)]
struct RuleControls {
    once_scope: Button,
    instance_scope: Button,
    app_scope: Button,
    project_scope: Button,
    read_access: Option<Button>,
    write_access: Option<Button>,
    read_write_access: Option<Button>,
    path_scope: Option<HoldBrowser>,
    path_candidates: Vec<String>,
    summary: Frame,
    window: Window,
    allow: Button,
    deny: Button,
}

const WINDOW_WIDTH: i32 = 520;
const MARGIN: i32 = 18;
const CONTENT_X: i32 = MARGIN;
const CONTENT_W: i32 = WINDOW_WIDTH - MARGIN * 2;
const HEADER_TOP: i32 = 18;
const EYEBROW_H: i32 = 14;
const TITLE_H: i32 = 34;
const DETAIL_ROW_H: i32 = 18;
const DETAIL_PAD: i32 = 16;
const DETAIL_MAX_ROWS: i32 = 8;
const SECTION_GAP: i32 = 14;
const CONTROL_H: i32 = 30;
const PATH_LIST_H: i32 = 74;
const SUMMARY_LINE_H: i32 = 22;
const SUMMARY_PAD: i32 = 12;
const SUMMARY_WRAP_CHARS: usize = 38;
const BUTTON_H: i32 = 32;
const SEGMENT_GAP: i32 = 6;

struct Layout {
    detail_y: i32,
    detail_h: i32,
    scope_y: i32,
    access_y: Option<i32>,
    path_y: Option<i32>,
    summary_y: i32,
    summary_h: i32,
    button_y: i32,
    height: i32,
}

struct PromptInput {
    details: PromptDetails,
    json_response: bool,
}

fn wrapped_line_count(text: &str, width: usize) -> usize {
    let width = width.max(1);
    let mut lines = 1usize;
    let mut col = 0usize;
    for word in text.split(' ') {
        let word_len = word.chars().count();
        if col != 0 && col + 1 + word_len <= width {
            col += 1 + word_len;
            continue;
        }
        if col != 0 {
            lines += 1;
        }
        if word_len <= width {
            col = word_len;
        } else {
            lines += (word_len - 1) / width;
            col = word_len - (word_len - 1) / width * width;
        }
    }
    lines
}

fn summary_h_for(text: &str) -> i32 {
    wrapped_line_count(text, SUMMARY_WRAP_CHARS) as i32 * SUMMARY_LINE_H + SUMMARY_PAD
}

fn initial_layout(details: &PromptDetails) -> Layout {
    let text = rule_summary(RuleSelection::for_details(details), details);
    layout_for(details, summary_h_for(&text))
}

fn move_to_y<W: WidgetExt>(widget: &mut W, y: i32) {
    let (x, w, h) = (widget.x(), widget.w(), widget.h());
    widget.resize(x, y, w, h);
}

// Resize the window and shift everything below the preview so the dialog always
// fits the current preview exactly, however many lines it wraps to.
fn apply_dynamic_layout(controls: &mut RuleControls, details: &PromptDetails, summary_text: &str) {
    let summary_h = summary_h_for(summary_text);
    if summary_h == controls.summary.h() {
        return;
    }
    let layout = layout_for(details, summary_h);
    controls
        .summary
        .resize(CONTENT_X, layout.summary_y, CONTENT_W, layout.summary_h);
    if let (Some(browser), Some(y)) = (controls.path_scope.as_mut(), layout.path_y) {
        move_to_y(browser, y);
    }
    if let Some(y) = layout.access_y {
        if let Some(button) = controls.read_access.as_mut() {
            move_to_y(button, y);
        }
        if let Some(button) = controls.write_access.as_mut() {
            move_to_y(button, y);
        }
        if let Some(button) = controls.read_write_access.as_mut() {
            move_to_y(button, y);
        }
    }
    move_to_y(&mut controls.once_scope, layout.scope_y);
    move_to_y(&mut controls.instance_scope, layout.scope_y);
    move_to_y(&mut controls.app_scope, layout.scope_y);
    move_to_y(&mut controls.project_scope, layout.scope_y);
    move_to_y(&mut controls.allow, layout.button_y);
    move_to_y(&mut controls.deny, layout.button_y);
    let mut window = controls.window.clone();
    window.set_size(WINDOW_WIDTH, layout.height);
    window.redraw();
}

fn layout_for(details: &PromptDetails, summary_h: i32) -> Layout {
    let has_access = filesystem_access_from_details(details).is_some();
    let has_path = !path_candidates(details).is_empty();
    let rows = ((details.fields.len() + details.body.len()) as i32).clamp(1, DETAIL_MAX_ROWS);
    let detail_h = rows * DETAIL_ROW_H + DETAIL_PAD;

    let mut y = HEADER_TOP + EYEBROW_H + TITLE_H + 10;
    let detail_y = y;
    y += detail_h + SECTION_GAP;

    let summary_y = y;
    y += summary_h + SECTION_GAP;

    let path_y = if has_path {
        let control = y;
        y += PATH_LIST_H + SECTION_GAP;
        Some(control)
    } else {
        None
    };

    let access_y = if has_access {
        let control = y;
        y += CONTROL_H + SECTION_GAP;
        Some(control)
    } else {
        None
    };

    let scope_y = y;
    y += CONTROL_H + SECTION_GAP;

    let button_y = y;
    y += BUTTON_H + MARGIN;

    Layout {
        detail_y,
        detail_h,
        scope_y,
        access_y,
        path_y,
        summary_y,
        summary_h,
        button_y,
        height: y,
    }
}

fn segment_bounds(count: usize) -> Vec<(i32, i32)> {
    let count_i = count as i32;
    let segment = (CONTENT_W - SEGMENT_GAP * (count_i - 1)) / count_i;
    (0..count)
        .map(|index| {
            let index = index as i32;
            let x = CONTENT_X + index * (segment + SEGMENT_GAP);
            let width = if index == count_i - 1 {
                CONTENT_X + CONTENT_W - x
            } else {
                segment
            };
            (x, width)
        })
        .collect()
}

fn main() {
    condom::app::debug::log_startup("condom-approval");
    if let Err(error) = run() {
        condom::debug_log!("condom-approval error={error:#}");
        eprintln!("condom-approval: {error:#}");
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let cli = ApprovalCli::parse();
    if cli.probe_display {
        probe_display();
        return Ok(());
    }
    let input = match (cli.request_json, cli.message, cli.demo) {
        (Some(request_json), None, None) => {
            let request = serde_json::from_str::<ApprovalPromptRequest>(&request_json)
                .context("failed to parse approval request JSON")?;
            PromptInput {
                details: prompt_details_from_request(&request),
                json_response: true,
            }
        }
        (None, Some(message), None) => PromptInput {
            details: parse_prompt_details(&message),
            json_response: false,
        },
        (None, None, Some(demo)) => PromptInput {
            details: parse_prompt_details(&demo_message(demo)),
            json_response: false,
        },
        (None, None, None) => bail!("expected --request-json, --message, or --demo"),
        _ => bail!("use only one of --request-json, --message, or --demo"),
    };
    let details = input.details;
    let app = app::App::default().with_scheme(app::Scheme::Gtk);
    configure_app_colors();

    let (sender, receiver) = app::channel::<PromptResult>();
    let selection = Rc::new(RefCell::new(RuleSelection::for_details(&details)));
    let layout = initial_layout(&details);
    let mut window = approval_window(&details, &layout);
    let _ = detail_card(&details, &layout);
    let mut controls = rule_controls(&details, &layout, &window);

    window.end();
    wire_window_close(&mut window, sender);
    let shortcut_window = window.clone();
    wire_keyboard_shortcuts(
        &mut window,
        sender,
        Rc::clone(&selection),
        controls.clone(),
        shortcut_window,
        details.clone(),
    );
    wire_rule_controls(
        &mut controls,
        Rc::clone(&selection),
        window.clone(),
        sender,
        details.clone(),
    );
    refresh_rule_controls(&mut controls, selection.borrow().to_owned(), &details);
    window.set_xclass("condom-approval");
    window.show();
    register_window_manager_hints(&window);
    window.wait_for_expose();

    loop {
        if let Some(result) = receiver.recv() {
            print_prompt_result(result, input.json_response)?;
            return Ok(());
        }
        if !app.wait() {
            break;
        }
    }

    if let Some(result) = receiver.recv() {
        print_prompt_result(result, input.json_response)?;
        return Ok(());
    }

    Ok(())
}

fn probe_display() {
    let _app = app::App::default().with_scheme(app::Scheme::Gtk);
}

fn print_prompt_result(result: PromptResult, json_response: bool) -> Result<()> {
    condom::debug_log!(
        "approval gui result decision={:?} subject={} filesystem_access={:?} json_response={}",
        result.decision,
        result.subject.as_deref().unwrap_or("<none>"),
        result.filesystem_access,
        json_response,
    );
    if json_response {
        println!(
            "{}",
            serde_json::to_string(&ApprovalPromptResponse::from_prompt_result(result))
                .context("failed to encode approval response JSON")?
        );
    } else {
        println!("{}", result.response_line());
    }
    Ok(())
}

#[cfg(target_os = "linux")]
fn register_window_manager_hints(window: &Window) {
    x11::set_window_manager_hints(window.raw_handle());
}

#[cfg(not(target_os = "linux"))]
fn register_window_manager_hints(_window: &Window) {}

fn configure_app_colors() {
    app::background(243, 244, 247);
    app::background2(255, 255, 255);
    app::foreground(17, 24, 39);
    app::set_font_size(13);
}

fn approval_window(details: &PromptDetails, layout: &Layout) -> Window {
    let mut window = Window::new(0, 0, WINDOW_WIDTH, layout.height, "condom approval");
    window.set_color(rgb(243, 244, 247));
    window.make_resizable(false);
    center_window_on_pointer_screen(&mut window);

    let mut eyebrow = Frame::new(
        CONTENT_X,
        HEADER_TOP,
        CONTENT_W,
        EYEBROW_H,
        "CONDOM APPROVAL",
    );
    eyebrow.set_align(Align::Left | Align::Inside);
    eyebrow.set_label_size(11);
    eyebrow.set_label_font(Font::HelveticaBold);
    eyebrow.set_label_color(rgb(37, 99, 235));

    let mut title = Frame::new(
        CONTENT_X,
        HEADER_TOP + EYEBROW_H,
        CONTENT_W,
        TITLE_H,
        details.title.as_str(),
    );
    title.set_align(Align::Left | Align::Inside | Align::Wrap);
    title.set_label_size(16);
    title.set_label_font(Font::HelveticaBold);
    title.set_label_color(rgb(17, 24, 39));

    window
}

fn center_window_on_pointer_screen(window: &mut Window) {
    let work_area = app::Screen::work_area_mouse();
    let width = window.width();
    let height = window.height();
    let x = work_area.x + (work_area.w - width).max(0) / 2;
    let y = work_area.y + (work_area.h - height).max(0) / 2;

    window.resize(x, y, width, height);
    window.force_position(true);
}

fn detail_card(details: &PromptDetails, layout: &Layout) -> TextDisplay {
    let mut display = TextDisplay::new(CONTENT_X, layout.detail_y, CONTENT_W, layout.detail_h, "");
    display.set_color(Color::White);
    display.set_frame(FrameType::BorderBox);
    display.set_text_color(rgb(30, 41, 59));
    display.set_text_font(Font::Helvetica);
    display.set_text_size(13);
    display.wrap_mode(WrapMode::AtBounds, 0);
    if (details.fields.len() + details.body.len()) as i32 <= DETAIL_MAX_ROWS {
        display.set_scrollbar_size(0);
    }
    display.set_buffer(prompt_text_buffer(details));
    display
}

fn prompt_text_buffer(details: &PromptDetails) -> TextBuffer {
    let mut buffer = TextBuffer::default();
    buffer.set_text(&prompt_text(details));
    buffer
}

fn prompt_text(details: &PromptDetails) -> String {
    let mut lines = Vec::new();
    for (name, value) in &details.fields {
        lines.push(format!("{name} {value}"));
    }
    lines.extend(details.body.iter().cloned());
    lines.join("\n")
}

fn rule_controls(details: &PromptDetails, layout: &Layout, window: &Window) -> RuleControls {
    let path_candidates = path_candidates(details);

    let scope = segment_bounds(4);
    let once_scope = rule_button(scope[0].0, layout.scope_y, scope[0].1, "Once");
    let instance_scope = rule_button(scope[1].0, layout.scope_y, scope[1].1, "Session");
    let app_scope = rule_button(scope[2].0, layout.scope_y, scope[2].1, "Program");
    let project_scope = rule_button(scope[3].0, layout.scope_y, scope[3].1, "Project");

    let (read_access, write_access, read_write_access) = if let Some(y) = layout.access_y {
        let access = segment_bounds(3);
        let read_access = rule_button(access[0].0, y, access[0].1, "Read");
        let write_access = rule_button(access[1].0, y, access[1].1, "Write");
        let read_write_access = rule_button(access[2].0, y, access[2].1, "Read + Write");
        (
            Some(read_access),
            Some(write_access),
            Some(read_write_access),
        )
    } else {
        (None, None, None)
    };

    let path_scope = if let Some(y) = layout.path_y {
        let mut browser = HoldBrowser::new(CONTENT_X, y, CONTENT_W, PATH_LIST_H, "");
        browser.set_color(Color::White);
        browser.set_frame(FrameType::BorderBox);
        browser.set_text_size(13);
        for (index, candidate) in path_candidates.iter().enumerate() {
            browser.add(&path_candidate_label(index, candidate));
        }
        browser.select(1);
        Some(browser)
    } else {
        None
    };

    let mut summary = Frame::new(CONTENT_X, layout.summary_y, CONTENT_W, layout.summary_h, "");
    summary.set_align(Align::Left | Align::Inside | Align::Wrap);
    summary.set_label_size(16);
    summary.set_label_font(Font::HelveticaBold);
    summary.set_label_color(rgb(17, 24, 39));

    let allow = primary_button(CONTENT_X + CONTENT_W - 150, layout.button_y, 150, "Allow");
    let deny = secondary_button(
        CONTENT_X + CONTENT_W - 150 - 8 - 150,
        layout.button_y,
        150,
        "Deny",
    );

    RuleControls {
        once_scope,
        instance_scope,
        app_scope,
        project_scope,
        read_access,
        write_access,
        read_write_access,
        path_scope,
        path_candidates,
        summary,
        window: window.clone(),
        allow,
        deny,
    }
}

fn rule_button(x: i32, y: i32, width: i32, label: &str) -> Button {
    let mut button = Button::new(x, y, width, CONTROL_H, label);
    button.set_frame(FrameType::ThinUpBox);
    button.set_label_size(12);
    button
}

fn primary_button(x: i32, y: i32, width: i32, label: &str) -> Button {
    let mut button = Button::new(x, y, width, BUTTON_H, label);
    button.set_color(rgb(37, 99, 235));
    button.set_selection_color(rgb(29, 78, 216));
    button.set_label_color(Color::White);
    button.set_label_size(13);
    button.set_label_font(Font::HelveticaBold);
    button.set_frame(FrameType::ThinUpBox);
    button
}

fn secondary_button(x: i32, y: i32, width: i32, label: &str) -> Button {
    let mut button = Button::new(x, y, width, BUTTON_H, label);
    button.set_frame(FrameType::ThinUpBox);
    button.set_color(rgb(226, 231, 239));
    button.set_selection_color(rgb(210, 216, 227));
    button.set_label_color(rgb(185, 28, 28));
    button.set_label_size(13);
    button.set_label_font(Font::HelveticaBold);
    button
}

fn field_value<'a>(details: &'a PromptDetails, name: &str) -> Option<&'a str> {
    let field_name = format!("{name}:");
    details
        .fields
        .iter()
        .find(|(field, _value)| field == &field_name)
        .map(|(_field, value)| value.as_str())
}

fn compact_label_value(value: &str, max_chars: usize) -> String {
    if value.chars().count() <= max_chars {
        return value.into();
    }
    let mut compact = value
        .chars()
        .take(max_chars.saturating_sub(3))
        .collect::<String>();
    compact.push_str("...");
    compact
}

fn filesystem_access_from_details(details: &PromptDetails) -> Option<FilesystemAccessMode> {
    field_value(details, "action").and_then(FilesystemAccessMode::parse)
}

fn path_candidates(details: &PromptDetails) -> Vec<String> {
    let home = std::env::var_os("HOME").map(PathBuf::from);
    path_candidates_with_home(details, home.as_deref())
}

fn path_candidates_with_home(details: &PromptDetails, home: Option<&Path>) -> Vec<String> {
    let Some(path) = field_value(details, "path") else {
        return Vec::new();
    };
    let canonical_home = home.and_then(|home| std::fs::canonicalize(home).ok());
    let mut ancestors = Path::new(path).ancestors();
    let Some(exact) = ancestors.next() else {
        return Vec::new();
    };
    if unsafe_persistent_subject(exact, home, canonical_home.as_deref()) {
        return Vec::new();
    }
    let mut candidates = vec![exact.display().to_string()];
    for ancestor in ancestors {
        if unsafe_persistent_subject(ancestor, home, canonical_home.as_deref()) {
            break;
        }
        if !ancestor.as_os_str().is_empty() {
            candidates.push(ancestor.display().to_string());
        }
    }
    candidates
}

fn unsafe_persistent_subject(
    candidate: &Path,
    home: Option<&Path>,
    canonical_home: Option<&Path>,
) -> bool {
    if candidate == Path::new("/") || home.is_some_and(|home| candidate == home) {
        return true;
    }
    let Ok(canonical) = std::fs::canonicalize(candidate) else {
        return false;
    };
    canonical == Path::new("/") || canonical_home.is_some_and(|home| canonical == home)
}

fn path_candidate_label(index: usize, candidate: &str) -> String {
    let prefix = if index == 0 { "exact" } else { "parent" };
    format!("{prefix}: {}", compact_label_value(candidate, 82))
}

fn selected_path_candidate(candidates: &[String], selected_index: i32) -> Option<String> {
    candidates
        .get(selected_index.saturating_sub(1) as usize)
        .cloned()
        .or_else(|| candidates.first().cloned())
}

fn rgb(red: u8, green: u8, blue: u8) -> Color {
    Color::from_rgb(red, green, blue)
}

fn wire_window_close(window: &mut Window, sender: app::Sender<PromptResult>) {
    window.set_callback(move |window| {
        sender.send(PromptResult::new(PromptDecision::DenyOnce));
        window.hide();
    });
}

fn wire_rule_controls(
    controls: &mut RuleControls,
    selection: Rc<RefCell<RuleSelection>>,
    mut window: Window,
    sender: app::Sender<PromptResult>,
    details: PromptDetails,
) {
    let once_controls = controls.clone();
    wire_scope_button(
        &mut controls.once_scope,
        RuleScope::Once,
        Rc::clone(&selection),
        once_controls,
        details.clone(),
    );
    let instance_controls = controls.clone();
    wire_scope_button(
        &mut controls.instance_scope,
        RuleScope::Instance,
        Rc::clone(&selection),
        instance_controls,
        details.clone(),
    );
    let app_controls = controls.clone();
    wire_scope_button(
        &mut controls.app_scope,
        RuleScope::AppProject,
        Rc::clone(&selection),
        app_controls,
        details.clone(),
    );
    let project_controls = controls.clone();
    wire_scope_button(
        &mut controls.project_scope,
        RuleScope::Project,
        Rc::clone(&selection),
        project_controls,
        details.clone(),
    );
    let access_controls = controls.clone();
    if let Some(read_access) = controls.read_access.as_mut() {
        wire_access_button(
            read_access,
            FilesystemAccessMode::Read,
            Rc::clone(&selection),
            access_controls,
            details.clone(),
        );
    }
    let access_controls = controls.clone();
    if let Some(write_access) = controls.write_access.as_mut() {
        wire_access_button(
            write_access,
            FilesystemAccessMode::Write,
            Rc::clone(&selection),
            access_controls,
            details.clone(),
        );
    }
    let access_controls = controls.clone();
    if let Some(read_write_access) = controls.read_write_access.as_mut() {
        wire_access_button(
            read_write_access,
            FilesystemAccessMode::ReadWrite,
            Rc::clone(&selection),
            access_controls,
            details.clone(),
        );
    }
    let path_controls = controls.clone();
    let path_candidates = controls.path_candidates.clone();
    if let Some(path_scope) = controls.path_scope.as_mut() {
        let path_selection = Rc::clone(&selection);
        let path_details = details.clone();
        let mut path_controls = path_controls;
        path_scope.set_callback(move |browser| {
            path_selection.borrow_mut().subject =
                selected_path_candidate(&path_candidates, browser.value());
            refresh_rule_controls(
                &mut path_controls,
                path_selection.borrow().clone(),
                &path_details,
            );
        });
    }

    let allow_selection = Rc::clone(&selection);
    controls.allow.set_callback({
        let mut window = window.clone();
        move |_| {
            allow_selection.borrow_mut().action = RuleAction::Allow;
            sender.send(allow_selection.borrow().result());
            window.hide();
        }
    });
    let deny_selection = Rc::clone(&selection);
    controls.deny.set_callback(move |_| {
        deny_selection.borrow_mut().action = RuleAction::Deny;
        sender.send(deny_selection.borrow().result());
        window.hide();
    });
}

fn wire_scope_button(
    button: &mut Button,
    scope: RuleScope,
    selection: Rc<RefCell<RuleSelection>>,
    mut controls: RuleControls,
    details: PromptDetails,
) {
    button.set_callback(move |_| {
        if scope != RuleScope::Once && !selection.borrow().persistent_scope_allowed {
            return;
        }
        selection.borrow_mut().scope = scope;
        refresh_rule_controls(&mut controls, selection.borrow().clone(), &details);
    });
}

fn wire_access_button(
    button: &mut Button,
    filesystem_access: FilesystemAccessMode,
    selection: Rc<RefCell<RuleSelection>>,
    mut controls: RuleControls,
    details: PromptDetails,
) {
    button.set_callback(move |_| {
        selection.borrow_mut().filesystem_access = Some(filesystem_access);
        refresh_rule_controls(&mut controls, selection.borrow().clone(), &details);
    });
}

fn wire_keyboard_shortcuts(
    window: &mut Window,
    sender: app::Sender<PromptResult>,
    selection: Rc<RefCell<RuleSelection>>,
    mut controls: RuleControls,
    mut shortcut_window: Window,
    details: PromptDetails,
) {
    window.handle(move |_, event| match event {
        Event::KeyDown | Event::Shortcut => {
            if app::event_key() == Key::Escape {
                sender.send(PromptResult::new(PromptDecision::DenyOnce));
                shortcut_window.hide();
                return true;
            }
            if let Some(action) = commit_action_for_event() {
                selection.borrow_mut().action = action;
                sender.send(selection.borrow().result());
                shortcut_window.hide();
                return true;
            }
            if let Some(update) = selection_update_for_event() {
                {
                    let mut selection = selection.borrow_mut();
                    match update {
                        SelectionUpdate::Scope(scope)
                            if scope == RuleScope::Once || selection.persistent_scope_allowed =>
                        {
                            selection.scope = scope
                        }
                        SelectionUpdate::Scope(_) => {}
                        SelectionUpdate::Access(filesystem_access)
                            if selection.filesystem_access.is_some() =>
                        {
                            selection.filesystem_access = Some(filesystem_access)
                        }
                        SelectionUpdate::Access(_) => {}
                    }
                }
                refresh_rule_controls(&mut controls, selection.borrow().clone(), &details);
                return true;
            }
            false
        }
        _ => false,
    });
}

#[derive(Clone, Copy)]
enum SelectionUpdate {
    Scope(RuleScope),
    Access(FilesystemAccessMode),
}

fn commit_action_for_event() -> Option<RuleAction> {
    if app::event_key() == Key::Enter {
        return Some(RuleAction::Allow);
    }
    match app::event_text().as_str() {
        "a" | "A" => Some(RuleAction::Allow),
        "d" | "D" => Some(RuleAction::Deny),
        _ => None,
    }
}

fn selection_update_for_event() -> Option<SelectionUpdate> {
    match app::event_text().as_str() {
        "o" | "O" => Some(SelectionUpdate::Scope(RuleScope::Once)),
        "i" | "I" => Some(SelectionUpdate::Scope(RuleScope::Instance)),
        "p" | "P" => Some(SelectionUpdate::Scope(RuleScope::AppProject)),
        "x" | "X" => Some(SelectionUpdate::Scope(RuleScope::Project)),
        "r" | "R" => Some(SelectionUpdate::Access(FilesystemAccessMode::Read)),
        "w" | "W" => Some(SelectionUpdate::Access(FilesystemAccessMode::Write)),
        "b" | "B" => Some(SelectionUpdate::Access(FilesystemAccessMode::ReadWrite)),
        _ => None,
    }
}

impl RuleSelection {
    fn for_details(details: &PromptDetails) -> Self {
        let path_candidates = path_candidates(details);
        Self {
            action: RuleAction::Allow,
            scope: RuleScope::Once,
            subject: path_candidates.first().cloned(),
            filesystem_access: filesystem_access_from_details(details),
            persistent_scope_allowed: field_value(details, "path").is_none()
                || !path_candidates.is_empty(),
        }
    }

    fn decision(&self) -> PromptDecision {
        match (self.action, self.effective_scope()) {
            (RuleAction::Allow, RuleScope::Once) => PromptDecision::AllowOnce,
            (RuleAction::Allow, RuleScope::Instance) => PromptDecision::AllowInstance,
            (RuleAction::Allow, RuleScope::AppProject) => PromptDecision::AllowAppProject,
            (RuleAction::Allow, RuleScope::Project) => PromptDecision::AllowProject,
            (RuleAction::Deny, RuleScope::Once) => PromptDecision::DenyOnce,
            (RuleAction::Deny, RuleScope::Instance) => PromptDecision::DenyInstance,
            (RuleAction::Deny, RuleScope::AppProject) => PromptDecision::DenyAppProject,
            (RuleAction::Deny, RuleScope::Project) => PromptDecision::DenyProject,
        }
    }

    fn result(&self) -> PromptResult {
        let decision = self.decision();
        match (self.effective_scope(), &self.subject) {
            (RuleScope::Once, _) | (_, None) => PromptResult::new(decision),
            (_, Some(subject)) => PromptResult::with_subject_and_access(
                decision,
                subject.clone(),
                self.filesystem_access,
            ),
        }
    }

    fn effective_scope(&self) -> RuleScope {
        if self.persistent_scope_allowed {
            self.scope
        } else {
            RuleScope::Once
        }
    }
}

fn refresh_rule_controls(
    controls: &mut RuleControls,
    selection: RuleSelection,
    details: &PromptDetails,
) {
    style_toggle(
        &mut controls.once_scope,
        selection.scope == RuleScope::Once,
        rgb(37, 99, 235),
    );
    style_toggle(
        &mut controls.instance_scope,
        selection.scope == RuleScope::Instance,
        rgb(37, 99, 235),
    );
    style_toggle(
        &mut controls.app_scope,
        selection.scope == RuleScope::AppProject,
        rgb(37, 99, 235),
    );
    style_toggle(
        &mut controls.project_scope,
        selection.scope == RuleScope::Project,
        rgb(37, 99, 235),
    );
    for button in [
        &mut controls.instance_scope,
        &mut controls.app_scope,
        &mut controls.project_scope,
    ] {
        if selection.persistent_scope_allowed {
            button.activate();
        } else {
            button.deactivate();
        }
    }
    if let Some(button) = controls.read_access.as_mut() {
        style_toggle(
            button,
            selection.filesystem_access == Some(FilesystemAccessMode::Read),
            rgb(14, 165, 233),
        );
    }
    if let Some(button) = controls.write_access.as_mut() {
        style_toggle(
            button,
            selection.filesystem_access == Some(FilesystemAccessMode::Write),
            rgb(14, 165, 233),
        );
    }
    if let Some(button) = controls.read_write_access.as_mut() {
        style_toggle(
            button,
            selection.filesystem_access == Some(FilesystemAccessMode::ReadWrite),
            rgb(14, 165, 233),
        );
    }
    let summary_text = rule_summary(selection, details);
    controls.summary.set_label(&summary_text);
    apply_dynamic_layout(controls, details, &summary_text);
}

fn style_toggle(button: &mut Button, selected: bool, selected_color: Color) {
    button.set_frame(FrameType::ThinUpBox);
    if selected {
        button.set_color(selected_color);
        button.set_selection_color(selected_color);
        button.set_label_color(Color::White);
        button.set_label_font(Font::HelveticaBold);
    } else {
        button.set_color(rgb(226, 231, 239));
        button.set_selection_color(rgb(210, 216, 227));
        button.set_label_color(rgb(51, 65, 85));
        button.set_label_font(Font::Helvetica);
    }
    button.redraw();
}

fn rule_summary(selection: RuleSelection, details: &PromptDetails) -> String {
    let action = match selection.action {
        RuleAction::Allow => "Allow",
        RuleAction::Deny => "Deny",
    };
    let subject = approval_subject(&selection, details);
    let target = match selection.filesystem_access {
        Some(FilesystemAccessMode::Read) => format!("reading {subject}"),
        Some(FilesystemAccessMode::Write) => format!("writing {subject}"),
        Some(FilesystemAccessMode::ReadWrite) => format!("reading and writing {subject}"),
        None => subject,
    };
    let scope = match selection.scope {
        RuleScope::Once => "just this once".to_string(),
        RuleScope::Instance => "for this session".to_string(),
        RuleScope::AppProject => format!("for {} in this project", prompt_app_name(details)),
        RuleScope::Project => "for any app in this project".to_string(),
    };

    format!("{action} {target} {scope}")
}

fn prompt_app_name(details: &PromptDetails) -> String {
    compact_label_value(field_value(details, "app").unwrap_or("this app"), 16)
}

fn approval_subject(selection: &RuleSelection, details: &PromptDetails) -> String {
    if selection.scope != RuleScope::Once {
        if let Some(subject) = &selection.subject {
            return compact_label_value(subject, 54);
        }
    }
    for field in ["path", "destination"] {
        if let Some(value) = field_value(details, field) {
            return compact_label_value(value, 54);
        }
    }
    "this request".into()
}

fn parse_prompt_details(message: &str) -> PromptDetails {
    let mut lines = message.lines();
    let title = lines
        .next()
        .map(clean_title)
        .filter(|line| !line.is_empty())
        .unwrap_or_else(|| "Approval requested".into());
    let mut fields = Vec::new();
    let mut body = Vec::new();

    for line in lines {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with("Choices:") {
            continue;
        }
        if let Some((name, value)) = trimmed.split_once(':') {
            fields.push((format!("{name}:"), value.trim().into()));
        } else {
            body.push(trimmed.into());
        }
    }

    PromptDetails {
        title,
        fields,
        body,
    }
}

fn prompt_details_from_request(request: &ApprovalPromptRequest) -> PromptDetails {
    PromptDetails {
        title: clean_title(&request.title),
        fields: request
            .fields
            .iter()
            .map(|field| (format!("{}:", field.name), field.value.clone()))
            .collect(),
        body: request.body.clone(),
    }
}

fn clean_title(line: &str) -> String {
    let trimmed = line.trim().trim_end_matches(':').trim();
    let mut chars = trimmed.chars();
    match chars.next() {
        Some(first) => first.to_uppercase().collect::<String>() + chars.as_str(),
        None => String::new(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use condom::auth::prompt::ApprovalPromptField;

    #[test]
    fn structured_request_builds_prompt_details_without_message_parsing() {
        let request = ApprovalPromptRequest::new(
            "condom blocked filesystem access",
            vec![
                ApprovalPromptField::new("action", "write"),
                ApprovalPromptField::new("path", "/tmp/cache"),
            ],
            vec!["extra context".into()],
        );

        let details = prompt_details_from_request(&request);

        assert_eq!(details.title, "Condom blocked filesystem access");
        assert_eq!(
            details.fields,
            vec![
                ("action:".into(), "write".into()),
                ("path:".into(), "/tmp/cache".into())
            ]
        );
        assert_eq!(details.body, vec!["extra context"]);
    }

    #[test]
    fn summary_grows_to_fit_multiline_preview() {
        let fs = parse_prompt_details(&demo_message(DemoShape::FsReadWrite));
        let fs_text = rule_summary(RuleSelection::for_details(&fs), &fs);
        assert!(summary_h_for(&fs_text) >= 3 * SUMMARY_LINE_H + SUMMARY_PAD);
        let proxy = parse_prompt_details(&demo_message(DemoShape::Proxy));
        let proxy_text = rule_summary(RuleSelection::for_details(&proxy), &proxy);
        assert!(summary_h_for(&fs_text) > summary_h_for(&proxy_text));
    }

    #[test]
    fn wrapped_line_count_handles_wrapping_and_long_tokens() {
        assert_eq!(wrapped_line_count("one two three", 40), 1);
        assert_eq!(wrapped_line_count("one two three", 7), 2);
        assert!(wrapped_line_count(&"x".repeat(90), 40) >= 3);
    }

    #[test]
    fn clean_title_sentence_cases_and_trims() {
        assert_eq!(
            clean_title("condom blocked filesystem access:"),
            "Condom blocked filesystem access"
        );
        assert_eq!(clean_title(""), "");
    }

    #[test]
    fn demo_shapes_produce_distinct_increasing_layouts() {
        let proxy = initial_layout(&parse_prompt_details(&demo_message(DemoShape::Proxy))).height;
        let path = initial_layout(&parse_prompt_details(&demo_message(DemoShape::Path))).height;
        let filesystem =
            initial_layout(&parse_prompt_details(&demo_message(DemoShape::FsRead))).height;

        assert!(path > proxy, "path shape adds a path-scope section");
        assert!(
            filesystem > path,
            "filesystem shape adds the access section"
        );
        assert!(path_candidates(&parse_prompt_details(&demo_message(DemoShape::Proxy))).is_empty());
    }

    #[test]
    fn filesystem_demos_select_the_expected_access_mode() {
        assert_eq!(
            filesystem_access_from_details(&parse_prompt_details(&demo_message(DemoShape::FsRead))),
            Some(FilesystemAccessMode::Read)
        );
        assert_eq!(
            filesystem_access_from_details(&parse_prompt_details(&demo_message(
                DemoShape::FsWrite
            ))),
            Some(FilesystemAccessMode::Write)
        );
        assert_eq!(
            filesystem_access_from_details(&parse_prompt_details(&demo_message(
                DemoShape::FsReadWrite
            ))),
            Some(FilesystemAccessMode::ReadWrite)
        );
    }

    #[test]
    fn path_candidates_stop_before_home_and_root() {
        let details = parse_prompt_details(
            "condom blocked filesystem access:\n  path: /home/example/.agent/config.toml",
        );

        assert_eq!(
            path_candidates_with_home(&details, Some(Path::new("/home/example"))),
            vec!["/home/example/.agent/config.toml", "/home/example/.agent",]
        );

        let system =
            parse_prompt_details("condom blocked filesystem access:\n  path: /etc/resolv.conf");
        assert_eq!(
            path_candidates_with_home(&system, Some(Path::new("/home/example"))),
            vec!["/etc/resolv.conf", "/etc"]
        );

        for path in ["/home/example", "/"] {
            let details = parse_prompt_details(&format!(
                "condom blocked filesystem access:\n  path: {path}"
            ));
            assert!(
                path_candidates_with_home(&details, Some(Path::new("/home/example"))).is_empty()
            );
        }
    }

    #[test]
    fn path_candidates_stop_before_home_and_root_symlink_aliases() {
        let temp = tempfile::tempdir().unwrap();
        let home = temp.path().join("home");
        std::fs::create_dir_all(home.join(".agent")).unwrap();
        let home_alias = temp.path().join("home-alias");
        std::os::unix::fs::symlink(&home, &home_alias).unwrap();
        let home_path = home_alias.join(".agent/config.toml");
        let details = parse_prompt_details(&format!(
            "condom blocked filesystem access:\n  path: {}",
            home_path.display()
        ));

        assert_eq!(
            path_candidates_with_home(&details, Some(&home)),
            vec![
                home_path.display().to_string(),
                home_alias.join(".agent").display().to_string(),
            ]
        );

        let root_alias = temp.path().join("root-alias");
        std::os::unix::fs::symlink("/", &root_alias).unwrap();
        let root_path = root_alias.join("etc/hosts");
        let details = parse_prompt_details(&format!(
            "condom blocked filesystem access:\n  path: {}",
            root_path.display()
        ));

        assert_eq!(
            path_candidates_with_home(&details, Some(&home)),
            vec![
                root_path.display().to_string(),
                root_alias.join("etc").display().to_string(),
            ]
        );
    }

    #[test]
    fn unsafe_whole_home_or_root_subjects_cannot_be_persisted() {
        let home = std::env::var("HOME").unwrap();
        for path in [home.as_str(), "/"] {
            let details = parse_prompt_details(&format!(
                "condom blocked filesystem access:\n  action: read\n  path: {path}"
            ));
            let mut selection = RuleSelection::for_details(&details);
            selection.scope = RuleScope::Project;

            assert!(!selection.persistent_scope_allowed);
            assert_eq!(
                selection.result(),
                PromptResult::new(PromptDecision::AllowOnce)
            );
        }
    }

    #[test]
    fn for_details_preselects_the_requested_filesystem_access() {
        for (action, expected) in [
            ("read", FilesystemAccessMode::Read),
            ("write", FilesystemAccessMode::Write),
            ("read-write", FilesystemAccessMode::ReadWrite),
        ] {
            let details = parse_prompt_details(&format!(
                "condom blocked filesystem access:\n  action: {action}\n  path: /home/example/.agent/config.toml"
            ));
            assert_eq!(
                RuleSelection::for_details(&details).filesystem_access,
                Some(expected)
            );
        }

        let proxy = parse_prompt_details("condom blocked a proxy destination:\n  app: npm");
        assert_eq!(RuleSelection::for_details(&proxy).filesystem_access, None);
    }

    #[test]
    fn persistent_rule_selection_outputs_filesystem_access() {
        let details = parse_prompt_details(
            "condom blocked filesystem access:\n  action: read\n  path: /home/example/.agent/config.toml",
        );
        let mut selection = RuleSelection::for_details(&details);
        selection.scope = RuleScope::AppProject;
        selection.subject = Some("/home/example/.agent".into());
        selection.filesystem_access = Some(FilesystemAccessMode::ReadWrite);

        assert_eq!(
            selection.result().response_line(),
            "aa access=read-write subject=/home/example/.agent"
        );
    }

    #[test]
    fn instance_rule_selection_outputs_subject_and_filesystem_access() {
        let details = parse_prompt_details(
            "condom blocked filesystem access:\n  action: read\n  path: /home/example/.agent/config.toml",
        );
        let mut selection = RuleSelection::for_details(&details);
        selection.scope = RuleScope::Instance;
        selection.subject = Some("/home/example/.agent".into());
        selection.filesystem_access = Some(FilesystemAccessMode::ReadWrite);

        assert_eq!(
            selection.result().response_line(),
            "ai access=read-write subject=/home/example/.agent"
        );
    }

    #[test]
    fn deny_instance_rule_selection_outputs_subject_and_filesystem_access() {
        let details = parse_prompt_details(
            "condom blocked filesystem access:\n  action: write\n  path: /home/example/.agent/config.toml",
        );
        let mut selection = RuleSelection::for_details(&details);
        selection.action = RuleAction::Deny;
        selection.scope = RuleScope::Instance;
        selection.subject = Some("/home/example/.agent".into());
        selection.filesystem_access = Some(FilesystemAccessMode::Write);

        assert_eq!(
            selection.result().response_line(),
            "di access=write subject=/home/example/.agent"
        );
    }

    #[test]
    fn once_rule_selection_does_not_output_filesystem_access() {
        let details = parse_prompt_details(
            "condom blocked filesystem access:\n  action: read\n  path: /home/example/.agent/config.toml",
        );
        let mut selection = RuleSelection::for_details(&details);
        selection.filesystem_access = Some(FilesystemAccessMode::ReadWrite);

        assert_eq!(selection.result().response_line(), "o");
    }
}

#[cfg(target_os = "linux")]
mod x11 {
    use std::os::raw::{c_char, c_int, c_ulong, c_void};

    use super::CString;
    use fltk::window::RawHandle;

    const PROP_MODE_REPLACE: c_int = 0;
    const XA_ATOM: c_ulong = 4;
    const XA_STRING: c_ulong = 31;

    pub fn set_window_manager_hints(window: RawHandle) {
        unsafe {
            let display = XOpenDisplay(std::ptr::null());
            if display.is_null() {
                return;
            }

            set_atom_property(
                display,
                window,
                "_NET_WM_WINDOW_TYPE",
                &["_NET_WM_WINDOW_TYPE_DIALOG"],
            );
            set_atom_property(
                display,
                window,
                "_NET_WM_STATE",
                &["_NET_WM_STATE_ABOVE", "_NET_WM_STATE_MODAL"],
            );
            set_string_property(display, window, "WM_WINDOW_ROLE", "pop-up");
            XRaiseWindow(display, window);
            XFlush(display);
            XCloseDisplay(display);
        }
    }

    unsafe fn set_atom_property(
        display: *mut c_void,
        window: c_ulong,
        property: &str,
        values: &[&str],
    ) {
        let property = intern_atom(display, property);
        let values = values
            .iter()
            .map(|value| intern_atom(display, value))
            .collect::<Vec<_>>();
        XChangeProperty(
            display,
            window,
            property,
            XA_ATOM,
            32,
            PROP_MODE_REPLACE,
            values.as_ptr().cast(),
            values.len() as c_int,
        );
    }

    unsafe fn set_string_property(
        display: *mut c_void,
        window: c_ulong,
        property: &str,
        value: &str,
    ) {
        let property = intern_atom(display, property);
        XChangeProperty(
            display,
            window,
            property,
            XA_STRING,
            8,
            PROP_MODE_REPLACE,
            value.as_ptr(),
            value.len() as c_int,
        );
    }

    unsafe fn intern_atom(display: *mut c_void, name: &str) -> c_ulong {
        let name = CString::new(name).expect("X11 atom name contains no NUL bytes");
        XInternAtom(display, name.as_ptr(), 0)
    }

    unsafe extern "C" {
        fn XOpenDisplay(display_name: *const c_char) -> *mut c_void;
        fn XCloseDisplay(display: *mut c_void) -> c_int;
        fn XInternAtom(
            display: *mut c_void,
            atom_name: *const c_char,
            only_if_exists: c_int,
        ) -> c_ulong;
        fn XChangeProperty(
            display: *mut c_void,
            window: c_ulong,
            property: c_ulong,
            type_: c_ulong,
            format: c_int,
            mode: c_int,
            data: *const u8,
            nelements: c_int,
        ) -> c_int;
        fn XRaiseWindow(display: *mut c_void, window: c_ulong) -> c_int;
        fn XFlush(display: *mut c_void) -> c_int;
    }
}
