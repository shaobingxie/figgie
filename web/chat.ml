open Core_kernel.Std
open Incr_dom
open Vdom

open Figgie
open Market

module Message = struct
  type t =
    | Connected_to_server of Host_and_port.t
    | Disconnected_from_server
    | Other_login of Username.t
    | Chat of Username.t * string
    | Chat_failed of [ `Chat_disabled | `Not_logged_in ]
    | Player_joined_room of { player : Username.t; room_id : Lobby.Room.Id.t }
    | Joined_room of Lobby.Room.Id.t
    | New_round
    | Round_over of Protocol.Round_results.t
    | Order_reject of Order.t * Protocol.Order.error
    | Cancel_reject of [ `All | `Id of Order.Id.t ] * Protocol.Cancel.error
    [@@deriving sexp_of]
end

let history_id = "history"

module Model = struct
  type t =
    { messages  : Message.t Fqueue.t
    ; scrolling : Scrolling.Model.t
    }

  let initial =
    { messages = Fqueue.empty
    ; scrolling = Scrolling.Model.create ~id:history_id
    }

  let add_message t message =
    { t with messages = Fqueue.enqueue t.messages message }
end

module Action = struct
  type t =
    | Send_chat of string
    | Scroll_chat of Scrolling.Action.t
    [@@deriving sexp_of]
end

let apply_scrolling_action (t : Model.t) (act : Scrolling.Action.t) =
  { t with scrolling = Scrolling.apply_action t.scrolling act }

let view (t : Model.t) ~is_connected ~my_name ~(inject : Action.t -> _) =
  let node_of_message : Message.t -> _ =
    let horizontal_rule = Node.create "hr" [] [] in
    let status nodes = Node.li [Attr.class_ "status"] nodes in
    let error  nodes = Node.li [Attr.classes ["status"; "error"]] nodes in
    let simple mk fmt = ksprintf (fun s -> mk [Node.text s]) fmt in
    function
    | Connected_to_server where ->
      simple status !"Connected to %{Host_and_port}" where
    | Disconnected_from_server ->
      error
        [ Node.text "Disconnected"
        ; horizontal_rule
        ]
    | Other_login who ->
      simple status !"%{Username} connected" who
    | Chat (who, msg) ->
      Node.li []
        [ Hash_colour.username_span
            ~is_me:(Option.exists my_name ~f:(Username.equal who))
            who
        ; Node.text ": "
        ; Node.text msg
        ]
    | Chat_failed `Chat_disabled ->
      error [ Node.text "Chat system administratively disabled" ]
    | Chat_failed `Not_logged_in ->
      error [ Node.text "Must log in to chat" ]
    | Player_joined_room { player; room_id } ->
      simple status !"%{Username} joined %{Lobby.Room.Id}" player room_id
    | Joined_room room_id ->
      status
        [ horizontal_rule
        ; Node.text (sprintf !"Joined %{Lobby.Room.Id}" room_id)
        ]
    | New_round ->
      simple status "Everyone's ready: game is starting!"
    | Round_over results ->
      status
        [ Node.text "Time's up! The gold suit was "
        ; Node.span [Attr.classes [Card.Suit.name results.gold; "gold"]]
          [ Node.text (Card.Suit.to_utf8 results.gold)
          ; Node.text " "
          ; Node.text (Card.Suit.name results.gold)
          ]
        ; horizontal_rule
        ]
    | Order_reject (_order, reject) ->
      simple error !"%{sexp:Protocol.Order.error}" reject
    | Cancel_reject (_oid_or_all, reject) ->
      simple error !"%{sexp:Protocol.Cancel.error}" reject
  in
  Node.div [Attr.id "historycmd"]
    [ Node.ul
        [ Attr.id history_id
        ; Scrolling.on_scroll t.scrolling
            ~inject:(fun scroll -> inject (Scroll_chat scroll))
        ]
        (List.map (Fqueue.to_list t.messages) ~f:node_of_message)
    ; Widget.textbox ~id:Ids.cmdline
        ~disabled:(not is_connected)
        ~on_submit:(fun msg -> inject (Send_chat msg))
        ()
    ]

let on_display ~(old : Model.t) (new_ : Model.t) ~schedule_scroll =
  ignore old;
  Scrolling.on_display new_.scrolling ~schedule:schedule_scroll;
