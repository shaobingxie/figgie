open Core_kernel.Std
open Incr_dom
open Vdom

open Figgie

(* http://phrogz.net/css/distinct-colors.html *)
let colours =
  [|
    "#ff7070"; "#ff2321"; "#cfa191"; "#fea27a"; "#ff5800"
  ; "#d0b494"; "#d78e2b"; "#f5c000"; "#999600"; "#b1bd9d"
  ; "#a4d483"; "#3da600"; "#00ed76"; "#00daa4"; "#00b5ae"
  ; "#00ddff"; "#00b6ff"; "#a4bccb"; "#5e77ff"; "#aeb0ff"
  ; "#ff7fff"; "#cc9cc7"; "#d5c1d0"; "#ff68a6"; "#ff0063"
  ; "#c49196"
  |]

let username_colour u =
  colours.(Username.hash u mod Array.length colours)

let username_style ~is_me u =
  let colour = username_colour u in
  if is_me
  then [("color", "black"); ("background-color", colour)]
  else [("color", colour)]

let username_span ?(attrs=[]) ~is_me u =
  Node.span (Attr.style (username_style ~is_me u) :: attrs)
    [Node.text (Username.to_string u)]
