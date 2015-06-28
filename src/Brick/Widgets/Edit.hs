{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module Brick.Widgets.Edit
  ( Editor(editContents, editCursorPos, editorName, editDrawContents)
  , editor
  , editContentsL
  , editCursorPosL
  , editorNameL
  , renderEditor
  , editAttr
  )
where

import Control.Lens
import Data.Monoid ((<>))
import Graphics.Vty (Event(..), Key(..), Modifier(..))

import Brick.Core (Name, Location(..), HandleEvent(..), suffixLenses)
import Brick.Widgets.Core
import Brick.Util (clamp)
import Brick.AttrMap

data Editor =
    Editor { editContents :: !String
           , editCursorPos :: !Int
           , editDrawContents :: String -> Widget
           , editorName :: Name
           }

suffixLenses ''Editor

instance HandleEvent Editor where
    handleEvent e =
        case e of
            EvKey (KChar 'a') [MCtrl] -> gotoBOL
            EvKey (KChar 'e') [MCtrl] -> gotoEOL
            EvKey (KChar 'd') [MCtrl] -> deleteChar
            EvKey (KChar c) [] | c /= '\t' -> insertChar c
            EvKey KDel [] -> deleteChar
            EvKey KLeft [] -> moveLeft
            EvKey KRight [] -> moveRight
            EvKey KBS [] -> deletePreviousChar
            _ -> id

editSetCursorPos :: Int -> Editor -> Editor
editSetCursorPos pos e =
    let newCP = clamp 0 (length $ e^.editContentsL) pos
    in e & editCursorPosL .~ newCP

moveLeft :: Editor -> Editor
moveLeft e = editSetCursorPos (e^.editCursorPosL - 1) e

moveRight :: Editor -> Editor
moveRight e = editSetCursorPos (e^.editCursorPosL + 1) e

deletePreviousChar :: Editor -> Editor
deletePreviousChar e
  | e^.editCursorPosL == 0 = e
  | otherwise = deleteChar $ moveLeft e

gotoBOL :: Editor -> Editor
gotoBOL = editSetCursorPos 0

gotoEOL :: Editor -> Editor
gotoEOL e = editSetCursorPos (length $ e^.editContentsL) e

deleteChar :: Editor -> Editor
deleteChar e = e & editContentsL %~ listRemove (e^.editCursorPosL)

listRemove :: Int -> [a] -> [a]
listRemove i as
  | i >= 0 && i < length as = take i as <> drop (i + 1) as
  | otherwise = as

insertChar :: Char -> Editor -> Editor
insertChar c theEdit =
    theEdit & editContentsL %~ listInsert c (theEdit^.editCursorPosL)
            & editCursorPosL %~ (+ 1)

listInsert :: a -> Int -> [a] -> [a]
listInsert a i as = take i as ++ [a] ++ drop i as

editor :: Name -> (String -> Widget) -> String -> Editor
editor name draw s = Editor s (length s) draw name

editAttr :: AttrName
editAttr = "edit"

renderEditor :: Editor -> Widget
renderEditor e =
    let cursorLoc = Location (e^.editCursorPosL, 0)
    in withAttrName editAttr $
       vLimit 1 $
       viewport (e^.editorNameL) Horizontal $
       showCursor (e^.editorNameL) cursorLoc $
       visibleRegion cursorLoc (1, 1) $
       e^.editDrawContentsL $
       e^.editContentsL
