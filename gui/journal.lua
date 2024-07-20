-- Fort journal with a multi-line text editor
--@ module = true

local gui = require 'gui'
local widgets = require 'gui.widgets'
local utils = require 'utils'
local json = require 'json'
local text_editor = reqscript('internal/journal/text_editor')

local RESIZE_MIN = {w=32, h=10}

JOURNAL_PERSIST_KEY = 'journal'

journal_config = journal_config or json.open('dfhack-config/journal.json')

JournalWindow = defclass(JournalWindow, widgets.Window)
JournalWindow.ATTRS {
    frame_title='DF Journal',
    resizable=true,
    resize_min=RESIZE_MIN,
    frame_inset=0,
    content=''
}

function JournalWindow:init()
    local config_frame = copyall(journal_config.data.frame or {})
    self.frame = self:sanitizeFrame(config_frame)

    self:addviews({
        widgets.Panel{
            view_id='table_of_contents_panel',
            frame_title='Table of contents',
            frame_style = gui.FRAME_INTERIOR,

            resizable=true,

            frame_background = gui.CLEAR_PEN,

            resize_min={w=20},
            resize_anchors={r=true},
            frame={l=0, t=1, b=1, w=30},
            on_resize_begin=self:callback('onPanelResizeBegin'),
            on_resize_end=self:callback('onPanelResizeEnd'),
            subviews={
                widgets.List{
                    frame={l=1,t=1},
                    view_id='table_of_contents',
                    choices={},
                    on_submit=self:callback('onTableOfContentsSubmit')
                },
            }
        },
        text_editor.TextEditor{
            view_id='journal_editor',
            frame={t=2, b=1, l=31, r=0},
            resize_min={w=30, h=10},
            frame_inset={r=1},
            text=self.content,
            on_change=function(text) self:onTextChange(text) end
        },
    })
end

function JournalWindow:sanitizeFrame(frame)
    local w, h = dfhack.screen.getWindowSize()
    local min = RESIZE_MIN
    if frame.t and h - frame.t - (frame.b or 0) < min.h then
        frame.t = h - min.h
        frame.b = 0
    end
    if frame.b and h - frame.b - (frame.t or 0) < min.h then
        frame.b = h - min.h
        frame.t = 0
    end
    if frame.l and w - frame.l - (frame.r or 0) < min.w then
        frame.l = w - min.w
        frame.r = 0
    end
    if frame.r and w - frame.r - (frame.l or 0) < min.w then
        frame.r = w - min.w
        frame.l = 0
    end
    return frame
end

function JournalWindow:postUpdateLayout()
    self:saveConfig()
end

function JournalWindow:saveConfig()
    utils.assign(journal_config.data, {
        frame = self.frame
    })
    journal_config:write()
end

function JournalWindow:onPanelResizeBegin()
    self.resizing_panels = true
end

function JournalWindow:onPanelResizeEnd()
    self.resizing_panels = false
end

function JournalWindow:esnurePanelsRelSize()
    self.subviews.table_of_contents_panel.frame.w = math.min(
        self.subviews.table_of_contents_panel.frame.w,
        self.frame.w - self.subviews.journal_editor.resize_min.w
    )
    self.subviews.journal_editor.frame.l = self.subviews.table_of_contents_panel.frame.w + 1
end

function JournalWindow:preUpdateLayout()
    self:esnurePanelsRelSize()
end

function JournalWindow:onRenderBody(painter)
    if self.resizing_panels then
        self:esnurePanelsRelSize()
        self:updateLayout()
    end

    return JournalWindow.super.onRenderBody(self, painter)
end

function JournalWindow:onTableOfContentsSubmit(ind, choice)
    self.subviews.journal_editor:setCursor(choice.line_cursor)
    self.subviews.journal_editor:scrollToCursor(choice.line_cursor)
end

JournalScreen = defclass(JournalScreen, gui.ZScreen)
JournalScreen.ATTRS {
    focus_path='journal',
    save_on_change=true
}

function JournalScreen:init(options)
    local content = self:loadContextContent()

    self:addviews{
        JournalWindow{
            view_id='journal_window',
            frame={w=65, h=45},
            resizable=true,
            resize_min={w=50, h=20},
            frame_inset=0,
            content=content
        },
    }

    self:reloadTableOfContents(content)
end

function JournalScreen:loadContextContent()
    local site_data = dfhack.persistent.getSiteData(JOURNAL_PERSIST_KEY) or {
        text = {''}
    }
    return site_data.text ~= nil and site_data.text[1] or ''
end

function JournalScreen:onTextChange(text)
    self:saveContextContent(text)
    self:reloadTableOfContents(text)
end

function JournalScreen:reloadTableOfContents(text)
    local sections = {}

    local line_cursor = 1
    for line in text:gmatch("[^\n]*") do
        local header, section = line:match("^(#+)%s(.+)")
        if header ~= nil then
            table.insert(sections, {
                line_cursor=line_cursor,
                text=string.rep(" ", #header - 1) .. section,
            })
        end

        line_cursor = line_cursor + #line + 1
    end

    self.subviews.table_of_contents:setChoices(sections)
end

function JournalScreen:saveContextContent(text)
    if self.save_on_change and dfhack.isWorldLoaded() then
        dfhack.persistent.saveSiteData(JOURNAL_PERSIST_KEY, {text={text}})
    end
end

function JournalScreen:onDismiss()
    view = nil
end

function main()
    if not dfhack.isMapLoaded() or not dfhack.world.isFortressMode() then
        qerror('journal requires a fortress map to be loaded')
    end

    view = view and view:raise() or JournalScreen{}:show()
end

if not dfhack_flags.module then
    main()
end
