import React, { useEffect, useRef } from 'react';
import { Box, IconButton, Tooltip, Divider, TextField } from '@mui/material';
import {
  FormatBold,
  FormatItalic,
  FormatUnderlined,
  StrikethroughS,
  Title,
  LooksOne,
  LooksTwo,
  FormatListBulleted,
  FormatListNumbered,
  FormatQuote,
  Code,
  FormatAlignLeft,
  FormatAlignCenter,
  FormatAlignRight,
  Link as LinkIcon,
  Image as ImageIcon,
  Undo,
  Redo,
  HorizontalRule,
  FormatClear
} from '@mui/icons-material';

const toolbarButton = (title, onClick, Icon, disabled) => (
  <Tooltip title={title}>
    <span>
      <IconButton size="small" onClick={onClick} disabled={disabled}>
        <Icon fontSize="small" />
      </IconButton>
    </span>
  </Tooltip>
);

export default function RichTextEditor({ value, onChange, placeholder }) {
  const editorRef = useRef(null);

  // Keep editor HTML in sync when parent value changes (avoid cursor jump by not updating on each keystroke)
  useEffect(() => {
    const el = editorRef.current;
    if (!el) return;
    if (el.innerHTML !== (value || '')) {
      el.innerHTML = value || '';
    }
  }, [value]);

  const exec = (command, value = null) => {
    // Focus editor before executing command
    editorRef.current?.focus();
    document.execCommand(command, false, value);
    // Emit updated HTML
    onChange?.(editorRef.current?.innerHTML || '');
  };

  const applyHeading = (level) => {
    if (level === 0) {
      exec('formatBlock', 'P');
    } else {
      exec('formatBlock', `H${level}`);
    }
  };

  const onPaste = (e) => {
    // Basic paste handling: allow HTML but strip scripts using the browser's default sanitizer
    // For advanced sanitization, content will be sanitized on render/preview.
    // Here we just prevent dangerous attributes by letting browser paste as plain text if needed.
    // Keep default behavior for now to retain formatting.
  };

  const onInput = () => {
    onChange?.(editorRef.current?.innerHTML || '');
  };

  const insertLink = () => {
    const url = window.prompt('Enter URL');
    if (!url) return;
    exec('createLink', url);
  };

  const insertImage = () => {
    const url = window.prompt('Enter image URL');
    if (!url) return;
    exec('insertImage', url);
  };

  return (
    <Box>
      <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.5, alignItems: 'center', mb: 1 }}>
        {toolbarButton('Undo', () => exec('undo'), Undo)}
        {toolbarButton('Redo', () => exec('redo'), Redo)}
        <Divider orientation="vertical" flexItem sx={{ mx: 1 }} />
        {toolbarButton('Bold', () => exec('bold'), FormatBold)}
        {toolbarButton('Italic', () => exec('italic'), FormatItalic)}
        {toolbarButton('Underline', () => exec('underline'), FormatUnderlined)}
        {toolbarButton('Strikethrough', () => exec('strikeThrough'), StrikethroughS)}
        {toolbarButton('Clear formatting', () => exec('removeFormat'), FormatClear)}
        <Divider orientation="vertical" flexItem sx={{ mx: 1 }} />
        {toolbarButton('Heading 1', () => applyHeading(1), LooksOne)}
        {toolbarButton('Heading 2', () => applyHeading(2), LooksTwo)}
        {toolbarButton('Paragraph', () => applyHeading(0), Title)}
        <Divider orientation="vertical" flexItem sx={{ mx: 1 }} />
        {toolbarButton('Bulleted list', () => exec('insertUnorderedList'), FormatListBulleted)}
        {toolbarButton('Numbered list', () => exec('insertOrderedList'), FormatListNumbered)}
        {toolbarButton('Quote', () => exec('formatBlock', 'BLOCKQUOTE'), FormatQuote)}
        {toolbarButton('Code block', () => exec('formatBlock', 'PRE'), Code)}
        <Divider orientation="vertical" flexItem sx={{ mx: 1 }} />
        {toolbarButton('Align left', () => exec('justifyLeft'), FormatAlignLeft)}
        {toolbarButton('Align center', () => exec('justifyCenter'), FormatAlignCenter)}
        {toolbarButton('Align right', () => exec('justifyRight'), FormatAlignRight)}
        <Divider orientation="vertical" flexItem sx={{ mx: 1 }} />
        {toolbarButton('Insert link', insertLink, LinkIcon)}
        {toolbarButton('Insert image', insertImage, ImageIcon)}
        {toolbarButton('Horizontal rule', () => exec('insertHorizontalRule'), HorizontalRule)}
      </Box>

      <Box
        ref={editorRef}
        contentEditable
        role="textbox"
        aria-multiline="true"
        onInput={onInput}
        onPaste={onPaste}
        sx={{
          border: '1px solid',
          borderColor: 'divider',
          borderRadius: 1,
          p: 2,
          minHeight: 200,
          outline: 'none',
          '&:empty:before': {
            content: `'${placeholder || 'Start typing…'}'`,
            color: 'text.disabled'
          },
          '& h1': { fontSize: '1.6rem', margin: 0 },
          '& h2': { fontSize: '1.3rem', margin: 0 },
          '& p, & li': { lineHeight: 1.7 },
          '& blockquote': {
            borderLeft: '4px solid',
            borderColor: 'divider',
            pl: 2,
            color: 'text.secondary'
          },
          '& pre': {
            backgroundColor: 'grey.100',
            p: 1,
            borderRadius: 1,
            fontFamily: 'monospace',
            overflowX: 'auto'
          }
        }}
        suppressContentEditableWarning
      />
    </Box>
  );
}
