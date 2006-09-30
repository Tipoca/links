module type Monad = 
sig
  type 'a m
  val return : 'a -> 'a m
  val fail : string -> 'a m
  val (>>=) : 'a m -> ('a -> 'b m) -> 'b m
  val (>>) : 'a m -> 'b m -> 'b m
end

module type MonadPlus =
sig
  include Monad
  val mzero : 'a m
  val mplus : 'a m -> 'a m -> 'a m
end

module MonadDefault
  (M : 
    sig
      type 'a m
      val return : 'a -> 'a m
      val fail : string -> 'a m
      val (>>=) : 'a m -> ('a -> 'b m) -> 'b m
    end) : Monad with type 'a m = 'a M.m =
struct
  include M
  let (>>) x y = x >>= (fun _ -> y)
end

module Monad_option : MonadPlus
  with type 'a m = 'a option =
struct
  include MonadDefault(
    struct
      type 'a m = 'a option
      let fail _ = None
      let return x = Some x
      let (>>=) x f = 
        match x with 
          | None    -> None
          | Some x  -> f x
    end)
  let mzero = None
  let mplus l r = match l, r with
    | None, r -> r
    | l,    _ -> l
end

module Monad_list : MonadPlus
  with type 'a m = 'a list =
struct
  include MonadDefault(
    struct
      type 'a m = 'a list
      let return x = [x]
      let fail _ = []
      let (>>=) m f = List.concat (List.map f m)
    end)
  let mzero = []
  let mplus = (@)
end

module IO =
        (struct
          type 'a m = unit -> 'a
          let return a = fun () -> a
          let (>>=) m k = 
            fun () ->
              let v = m () in
                k v ()
          let fail = failwith
          let putStr s = fun () -> print_string s
          let runIO f = f ()
        end)

(* Control.Monad *)
module MonadUtils (M : Monad) = 
struct
  include M
  let liftM : ('a1 -> 'r) -> 'a1 m -> 'r m
    = fun f m1 -> m1 >>= (fun x1 -> return (f x1))
  let liftM2 :  ('a1 -> 'a2 -> 'r) -> 'a1 m -> 'a2 m -> 'r m
    = fun f m1 m2
      -> m1 >>= (fun x1
      -> m2 >>= (fun x2
      -> return (f x1 x2)))
  let liftM3 :  ('a1 -> 'a2 -> 'a3 -> 'r) -> 'a1 m -> 'a2 m -> 'a3 m -> 'r m
    = fun f m1 m2 m3
      -> m1 >>= (fun x1
      -> m2 >>= (fun x2
      -> m3 >>= (fun x3
      -> return (f x1 x2 x3))))
  let liftM4 :  ('a1 -> 'a2 -> 'a3 -> 'a4 -> 'r) -> 'a1 m -> 'a2 m -> 'a3 m -> 'a4 m -> 'r m
    = fun f m1 m2 m3 m4
      -> m1 >>= (fun x1
      -> m2 >>= (fun x2
      -> m3 >>= (fun x3
      -> m4 >>= (fun x4
      -> return (f x1 x2 x3 x4)))))
  let liftM5  :  ('a1 -> 'a2 -> 'a3 -> 'a4 -> 'a5 -> 'r) -> 'a1 m -> 'a2 m -> 'a3 m -> 'a4 m -> 'a5 m -> 'r m
    = fun f m1 m2 m3 m4 m5 
      -> m1 >>= (fun x1
      -> m2 >>= (fun x2
      -> m3 >>= (fun x3
      -> m4 >>= (fun x4
      -> m5 >>= (fun x5
      -> return (f x1 x2 x3 x4 x5))))))
  let ap : ('a -> 'b) m -> 'a m -> 'b m
    = fun f -> liftM2 (fun x -> x) f

  let sequence : ('a m) list -> ('a list) m
    = let mcons p q = p >>= (fun x -> q >>= (fun y -> return (x::y)))
      in 
        fun l -> List.fold_right mcons l (return [])

  let sequence_ : ('a m) list -> unit m
    = fun l -> List.fold_right (>>) l (return  ())

  let mapM : ('a -> 'b m) -> 'a list -> ('b list) m
    = fun f xs -> sequence (List.map f xs)

  let mapM_ : ('a -> 'b m) -> 'a list -> unit m
    = fun f xs -> sequence_ (List.map f xs)

  let (=<<) : ('a -> 'b m) -> 'a m -> 'b m
    = fun f x -> x >>= f

  let join : ('a m) m -> 'a m
    = fun x -> x >>= (fun x -> x)

  let rec filterM : ('a -> bool m) -> 'a list -> ('a list) m
    = fun p -> function
      | []    -> return []
      | x::xs -> p x >>= (fun flg ->
                 filterM p xs >>= (fun ys ->
                 return (if flg then (x::ys) else ys)))

  let mapAndUnzipM : ('a -> ('b *'c) m) -> 'a list -> ('b list * 'c list) m
    = fun f xs -> sequence (List.map f xs) >>= fun x -> return (List.split x)

  let zipWithM : ('a -> 'b -> 'c m) -> 'a list -> 'b list -> ('c list) m
    = fun f xs ys -> sequence (List.map2 f xs ys)

  let zipWithM_ : ('a -> 'b -> 'c m) -> 'a list -> 'b list -> unit m
    = fun f xs ys -> sequence_ (List.map2 f xs ys)

  let rec foldM : ('a -> 'b -> 'a m) -> 'a -> 'b list -> 'a m 
    = fun f a -> function
      | []    -> return a
      | x::xs -> f a x >>= (fun fax -> foldM f fax xs)

  let foldM_ : ('a -> 'b -> 'a m) -> 'a -> 'b list -> unit m
    = fun f a xs -> foldM f a xs >> return ()

  let ((replicateM : int -> 'a m -> ('a list) m),
       (replicateM_ : int -> 'a m -> unit m))
      = let replicate n i = 
        let rec aux accum = function
          | 0 -> accum
          | n -> aux (i::accum) (n-1)
        in aux [] n
        in
          ((fun n x -> sequence (replicate n x)),
           (fun n x -> sequence_ (replicate n x)))

  let quand (* when *) : bool -> unit m -> unit m
    = fun p s -> if p then s else return ()

  let unless : bool -> unit m -> unit m
    = fun p s -> if p then return () else s
end

module MonadPlusUtils (M : MonadPlus) =
struct
  include MonadUtils(M)
  let mzero = M.mzero
  let mplus = M.mplus
  let guard : bool -> unit M.m
    = function
      | true   -> M.return ()
      | false  -> M.mzero

  let msum : ('a M.m) list -> 'a M.m
    = fun l -> List.fold_right M.mplus l M.mzero
end

module MonadPlusUtils_option = MonadPlusUtils(Monad_option)
module MonadPlusUtils_list = MonadPlusUtils(Monad_list)
module Monad_IO = MonadUtils(MonadDefault (IO))
