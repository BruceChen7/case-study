use crossterm::event::{self, Event, KeyCode, KeyEvent, KeyEventKind};
use ratatui::{
    prelude::*,
    widgets::{Cell, Paragraph, Row, Table, TableState},
    Frame,
};
use std::io::{self, Result};

mod tui;

#[derive(Debug, Default)]
pub struct AppTab {}

impl AppTab {
    pub fn render(&self, area: ratatui::layout::Rect, buf: &mut ratatui::buffer::Buffer) {
        let horizontal = Layout::horizontal([Constraint::Min(area.width)]);
        let [title] = horizontal.areas(area);

        let title_text =
            Text::styled("WU", Style::new().fg(Color::Green)).alignment(Alignment::Center);
        Paragraph::new(title_text)
            .alignment(Alignment::Center)
            .render(title, buf)
    }
}

#[derive(Debug, Default)]
struct Entry {
    url: String,
}

impl From<&str> for Entry {
    fn from(s: &str) -> Self {
        Self {
            url: String::from(s),
        }
    }
}

#[derive(Debug, Default)]
pub struct AppContent {
    entries: Vec<Entry>,
    select_entries_index: usize,
}

impl AppContent {
    pub fn new() -> Self {
        Self {
            entries: vec![
                Entry::from("https://www.baidu.com"),
                Entry::from("https://www.google.com"),
            ],
            select_entries_index: 0,
        }
    }

    pub fn render(&self, area: ratatui::layout::Rect, buf: &mut ratatui::buffer::Buffer) {
        let entries_area = area.inner(&Margin {
            vertical: 1,
            horizontal: 1,
        });
        let mut entries_state = TableState::new()
            .with_offset(0)
            .with_selected(self.select_entries_index);
        let header = Row::new(vec!["url", "description"]);
        let width = [Constraint::Percentage(80), Constraint::Percentage(20)];

        let row = Row::new([
            Cell::from("https://www.baidu.com").style(Color::Green),
            Cell::from("hello worldafafaf"),
        ]);
        let rows = vec![row];

        let whole_table = Table::new(rows, width)
            .header(header.style(Color::Green))
            .column_spacing(2)
            .highlight_symbol(" ")
            .highlight_style(Style::new().add_modifier(Modifier::BOLD))
            .highlight_spacing(ratatui::widgets::HighlightSpacing::WhenSelected);
        StatefulWidget::render(whole_table, entries_area, buf, &mut entries_state);
    }
}

#[derive(Debug, Default)]
pub struct AppInput {}

impl AppInput {
    pub fn render(&self, area: ratatui::layout::Rect, buf: &mut ratatui::buffer::Buffer) {}
}

#[derive(Debug, Default)]
pub struct App {
    exit: bool,
    pub tabs: AppTab,
    pub content: AppContent,
    pub input: AppInput,
}

impl App {
    pub fn run(&mut self, terminal: &mut tui::Tui) -> Result<()> {
        while !self.exit {
            terminal.draw(|frame| self.render_frame(frame))?;
            self.handle_event()?;
        }
        Ok(())
    }

    fn render_frame(&self, frame: &mut Frame) {
        frame.render_widget(self, frame.size())
    }

    fn handle_event(&mut self) -> io::Result<()> {
        match event::read()? {
            Event::Key(key_event) if key_event.kind == KeyEventKind::Press => {
                self.handle_key_event(key_event)
            }
            _ => {}
        }
        Ok(())
    }

    fn handle_key_event(&mut self, key_event: KeyEvent) {
        match key_event.code {
            KeyCode::Char('q') => self.exit(),
            _ => {}
        }
    }

    fn exit(&mut self) {
        self.exit = true;
    }
}

impl Widget for &App {
    fn render(self, area: ratatui::layout::Rect, buf: &mut ratatui::buffer::Buffer) {
        let layout = Layout::vertical([
            Constraint::Length(1),
            Constraint::Min(0),
            Constraint::Length(1),
        ]);
        let [tab_area, content_area, input_area] = layout.areas(area);
        self.tabs.render(tab_area, buf);
        self.content.render(content_area, buf);
        self.input.render(input_area, buf);
    }
}

fn main() -> io::Result<()> {
    let mut terminal = tui::init()?;
    let app_result = App::default().run(&mut terminal);
    tui::deinit()?;
    app_result
}
