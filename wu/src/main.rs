use crossterm::event::{self, Event, KeyCode, KeyEvent, KeyEventKind};
use ratatui::{prelude::*, widgets::Paragraph, Frame};
use std::io::{self, Result};

mod tui;

#[derive(Debug, Default)]
pub struct AppTab {}

impl AppTab {
    pub fn render(&self, area: ratatui::layout::Rect, buf: &mut ratatui::buffer::Buffer) {
        let horizontal = Layout::horizontal([Constraint::Min(0)]);
        let [title] = horizontal.areas(area);
        Paragraph::new(Span::styled("WU", Style::new().fg(Color::DarkGray))).render(title, buf)
    }
}

#[derive(Debug, Default)]
pub struct AppContent {}

impl AppContent {
    pub fn render(&self, area: ratatui::layout::Rect, buf: &mut ratatui::buffer::Buffer) {}
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
