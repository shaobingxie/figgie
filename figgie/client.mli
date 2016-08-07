open Async.Std

type t = {
  username : Username.t;
  conn : Rpc.Connection.t;
  updates : Protocol.Update.t Pipe.Reader.t;
  new_order_id : unit -> Market.Order.Id.t;
}

val make_command
  :  summary:string
  -> param:'a Command.Param.t
  -> username:('a -> Username.t)
  -> f:(t -> 'a -> unit Deferred.t)
  -> Command.t