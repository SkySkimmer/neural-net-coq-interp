From Coq.Structures Require Import Equalities.
From Coq Require Import ZArith Sint63 Uint63 List PArray Lia.
From NeuralNetInterp.Util Require Nat.
From NeuralNetInterp.Util Require Import Wf_Uint63 PArray.Proofs List.Proofs Default Pointed PArray List Notations Arith.Classes Arith.Instances Bool (*PrimitiveProd*).
Import Util.Nat.Notations.
Import Util.Wf_Uint63.LoopNotation.
Import Util.Wf_Uint63.Reduction.
Import Arith.Classes.
Local Open Scope list_scope.
Set Implicit Arguments.
Import ListNotations.
(*Import PrimitiveProd.Primitive.*)

Definition Rank := nat.
#[global] Bind Scope nat_scope with Rank.
#[local] Coercion is_true : bool >-> Sortclass.

Module Type IndexType.
  Parameter t : Type.
  Notation IndexType := t.
End IndexType.

Module Type ExtendedIndexType.
  Include IndexType.
  Parameter zero : has_zero t.
  Parameter one : has_one t.
  Parameter leb : has_leb t.
  Parameter ltb : has_ltb t.
  Parameter eqb : has_eqb t.
  Parameter mul : has_mul t.
  Parameter add : has_add t.
  Parameter int_div : has_int_div t.
  Parameter modulo : has_mod t.
  #[export] Existing Instances eqb one zero ltb leb mul add int_div modulo.
End ExtendedIndexType.

Module IndexGen.
  Module Make (IndexType : IndexType).
    Import (hints) IndexType.
    Notation IndexType := IndexType.t.

    Fixpoint t (r : Rank) : Type
      := match r with
         | O => unit
         | S r => t r * IndexType.t
         end.
    Notation Index := t.

    Definition nil : t 0 := tt.
    Definition snoc {r} (s : t r) x : t (S r) := (s, x).
    Module Import IndexNotations0.
      Declare Scope index_scope.
      Delimit Scope index_scope with index.
      Bind Scope index_scope with Index.
      Notation "xs ::' x" := (snoc xs x) : index_scope.
      Notation "[ ]" := nil : index_scope.
      Notation "[ x ]" := (snoc nil x) : index_scope.
      Notation "[ x ; y ; .. ; z ]" :=  (snoc .. (snoc (snoc nil x) y) .. z) : index_scope.
    End IndexNotations0.
    Module IndexPatternNotations.
      Declare Scope index_pattern_scope.
      Delimit Scope index_pattern_scope with index_pattern.
      Notation "xs ::' x" := (pair xs x) : index_pattern_scope.
      Notation "[ ]" := tt : index_pattern_scope.
      Notation "[ x ]" := (pair tt x) : index_pattern_scope.
      Notation "[ x ; y ; .. ; z ]" :=  (pair .. (pair (pair tt x) y) .. z) : index_pattern_scope.
    End IndexPatternNotations.
    #[local] Open Scope index_scope.
    Definition hd {r : Rank} : Index (S r) -> Index r := @fst _ _.
    Definition tl {r : Rank} : Index (S r) -> IndexType := @snd _ _.
    Fixpoint app {r1 r2 : Rank} {struct r2} : Index r1 -> Index r2 -> Index (r1 +' r2)
      := match r2 with
         | 0%nat => fun sz _tt => sz
         | S r2 => fun sz1 sz2 => @app r1 r2 sz1 (hd sz2) ::' tl sz2
         end%index.
    Definition cons {r : Rank} x (xs : Index r) : Index _ := app [x] xs.
    Module Export IndexNotations1.
      Include IndexNotations0.
      Notation "x :: xs" := (cons x xs) : index_scope.
      Notation "s1 ++ s2" := (app s1 s2) : index_scope.
      Notation "s1 ++' s2" := (app s1 s2) : index_scope.
    End IndexNotations1.

    Section repeat.
      Context (x : IndexType).
      Fixpoint repeat (r : Rank) : Index r
        := match r with
           | O => []
           | S r => repeat r ::' x
           end.

      Lemma hd_repeat {r} : hd (repeat (S r)) = repeat r.
      Proof using Type. reflexivity. Qed.

      Lemma tl_repeat {r} : tl (repeat (S r)) = x.
      Proof using Type. reflexivity. Qed.
    End repeat.

    Definition item : Index 1 -> IndexType := tl.

    Fixpoint map {r} (f : IndexType -> IndexType) : Index r -> Index r
      := match r with
         | 0%nat => fun _ => []
         | S r => fun xs => map f (hd xs) ::' f (tl xs)
         end.

    Fixpoint map2 {r} (f : IndexType -> IndexType -> IndexType) : Index r -> Index r -> Index r
      := match r with
         | 0%nat => fun _ _ => []
         | S r => fun xs ys => map2 f (hd xs) (hd ys) ::' f (tl xs) (tl ys)
         end.

    (* TODO: nary *)
    Fixpoint map3 {r} (f : IndexType -> IndexType -> IndexType -> IndexType) : Index r -> Index r -> Index r -> Index r
      := match r with
         | 0%nat => fun _ _ _ => []
         | S r => fun xs ys zs => map3 f (hd xs) (hd ys) (hd zs) ::' f (tl xs) (tl ys) (tl zs)
         end.

    Fixpoint fold_map {A B r} (f : IndexType -> A) (accum : B -> A -> B) (init : B) : Index r -> B
      := match r with
         | 0%nat => fun _ => init
         | S r => fun xs => fold_map f accum (accum init (f (tl xs))) (hd xs)
         end.

    Fixpoint fold_map2 {A B r} (f : IndexType -> IndexType -> A) (accum : B -> A -> B) (init : B) : Index r -> Index r -> B
      := match r with
         | 0%nat => fun _ _ => init
         | S r => fun xs ys => fold_map2 f accum (accum init (f (tl xs) (tl ys))) (hd xs) (hd ys)
         end.

    Fixpoint curriedT_dep {r : Rank} : (Index r -> Type) -> Type
      := match r with
         | O => fun f => f []
         | S r => fun f => curriedT_dep (fun init => forall i, f (init ::' i))
         end.
    Definition curriedT {r} (T : Type) : Type := @curriedT_dep r (fun _ => T).

    Fixpoint curry_dep {r} : forall {T}, (forall i : Index r, T i) -> @curriedT_dep r T
      := match r return forall {T}, (forall i : Index r, T i) -> @curriedT_dep r T with
         | O => fun T f => f []
         | S r => fun T f => @curry_dep r _ (fun rest i => f (rest ::' i))
         end.
    Definition curry {r T} : (Index r -> T) -> @curriedT r T
      := @curry_dep r (fun _ => T).
    Fixpoint uncurry_map_dep {r} : forall {A B}, (forall i, A i -> B i) -> @curriedT_dep r A -> (forall i : Index r, B i)
      := match r return forall {A B}, (forall i, A i -> B i) -> @curriedT_dep r A -> (forall i : Index r, B i) with
         | O => fun A B F f 'tt => F _ f
         | S r => fun A B F f '(rest, i)
                  => @uncurry_map_dep
                       r (fun rest => forall i, A (rest ::' i)) (fun rest => B (rest ::' i))
                       (fun rest f => F _ (f _))
                       f rest
         end.
    Definition uncurry_dep {r} {T} : @curriedT_dep r T -> (forall i : Index r, T i)
      := @uncurry_map_dep r T T (fun _ x => x).
    Definition uncurry {r T} : @curriedT r T -> (Index r -> T)
      := uncurry_dep.

    Fixpoint split_radd {r1 r2} {struct r2} : Index (r1 +' r2) -> Index r1 * Index r2
      := match r2 with
         | 0%nat => fun idx => (idx, tt)
         | S r2
           => fun '(idx1, idx2)
              => let '(idx11, idx12) := @split_radd r1 r2 idx1 in
                 (idx11, (idx12, idx2))
         end.
    Fixpoint combine_radd {r1 r2} {struct r2} : Index r1 * Index r2 -> Index (r1 +' r2)
      := match r2 return Index r1 * Index r2 -> Index (r1 +' r2) with
         | 0%nat => fun '(idx, tt) => idx
         | S r2
           => fun '(idx1, (idx2, idx3))
              => (@combine_radd r1 r2 (idx1, idx2), idx3)
         end.

    Definition curry_radd {A r1 r2} : (Index (r1 +' r2) -> A) -> (Index r1 -> Index r2 -> A)
      := fun f i1 i2 => f (combine_radd (i1, i2)).
    Definition uncurry_radd {A r1 r2} : (Index r1 -> Index r2 -> A) -> (Index (r1 +' r2) -> A)
      := fun f i => let '(i1, i2) := split_radd i in f i1 i2.
    Definition curry_S {A r} : (Index (1 +' r) -> A) -> (Index 1 -> Index r -> A)
      := curry_radd.
    Definition uncurry_S {A r} : (Index 1 -> Index r -> A) -> (Index (1 +' r) -> A)
      := uncurry_radd.

    Module UncurryNotation.
      Notation "'uncurry_fun' x1 .. xn => body"
        := (match _ return _ with
            | ty => uncurry_S (fun x1 => .. (uncurry_S (fun xn => match body return Index 0 -> ty with v => fun 'tt => v end)) .. )
            end)
             (only parsing, at level 200, x1 binder, xn binder, body at level 200).
    End UncurryNotation.

    Module Export IndexNotations.
      Include IndexNotations1.
      (*Include UncurryNotation.*)
    End IndexNotations.

    Module UncurryCoercions.
      Coercion uncurry_dep : curriedT_dep >-> Funclass.
      Coercion uncurry : curriedT >-> Funclass.
    End UncurryCoercions.

    Fixpoint droplastn {r : Rank} (n : Rank) : Index r -> Index (r -' n)
      := match n, r with
         | 0%nat, _ => fun xs => xs
         | _, 0%nat => fun _tt => []
         | S n, S r => fun xs => @droplastn r n (hd xs)
         end.

    Fixpoint lastn {r : Rank} (n : Rank) : Index r -> Index (Nat.min n r)
      := match n, r return Index r -> Index (Nat.min n r) with
         | 0%nat, _ => fun _ => []
         | _, 0%nat => fun _ => []
         | S n, S r => fun xs => lastn n (hd xs) ::' (tl xs)
         end.

    Fixpoint reduce {A} (reduction : A -> IndexType -> A) (init : A) {r} : Index r -> A
      := match r with
         | 0%nat => fun _ => init
         | S r => fun idxs => reduction (reduce reduction init (hd idxs)) (tl idxs)
         end.
  End Make.

  Module Type MakeSig (IndexType : IndexType) := Nop <+ Make IndexType.

  Module ExtendedMake (IndexType : ExtendedIndexType).
    Import (hints) IndexType.
    Include Make IndexType.
    Import IndexNotations.
    #[local] Open Scope index_scope.

    Definition ones {r} := repeat 1%core r.

    #[export] Instance eqb {r : Rank} : has_eqb (Index r)
      := fold_map2 IndexType.eqb andb true.
    #[export] Instance leb {r : Rank} : has_leb (Index r)
      := fold_map2 IndexType.leb andb true.
    #[export] Instance ltb {r : Rank} : has_ltb (Index r)
      := match r with O => fun _ _ => false | _ => fold_map2 IndexType.ltb andb true end.
    Lemma expand_eqb {r} (xs ys : Index (S r)) : ((xs =? ys) = ((hd xs =? hd ys) && (@Classes.eqb _ IndexType.eqb (tl xs) (tl ys))))%core%bool.
    Proof.
      cbv [Classes.eqb]; cbn.
      set (b := IndexType.eqb _ _); clearbody b.
      revert b; induction r as [|r IH]; cbn; try reflexivity; intros.
      rewrite !IH; destruct b, IndexType.eqb, eqb; reflexivity.
    Qed.
    Lemma expand_leb {r} (xs ys : Index (S r)) : ((xs <=? ys) = ((hd xs <=? hd ys) && (tl xs <=? tl ys)))%core%bool.
    Proof.
      cbv [Classes.leb]; cbn.
      set (b := IndexType.leb _ _); clearbody b.
      revert b; induction r as [|r IH]; cbn; try reflexivity; intros.
      rewrite !IH; destruct b, IndexType.leb, leb; reflexivity.
    Qed.
    Lemma expand_ltb {r} (xs ys : Index (S r)) : ((xs <? ys) = (match r with O => true | _ => hd xs <? hd ys end && (@Classes.ltb _ IndexType.ltb (tl xs) (tl ys))))%core%bool.
    Proof.
      cbv [Classes.ltb ltb]; cbn.
      set (b := IndexType.ltb _ _); clearbody b.
      revert b; induction r as [|r IH]; cbn; try reflexivity; intros.
      rewrite !IH; destruct b, IndexType.ltb, r; try reflexivity.
      all: destruct fold_map2; reflexivity.
    Qed.

    Module Rank.
      Fixpoint filter {r : Rank} (f : IndexType -> bool) : Index r -> Rank
        := match r with
           | 0%nat => fun _ => 0%nat
           | S r => fun idx => @filter r f (hd idx) +' if f (tl idx) then 1 else 0
           end.
      Definition squeeze {r : Rank} (i : Index r) : Rank
        := filter (fun i => (i != 1)%core) i.
    End Rank.
    Fixpoint filter {r : Rank} (f : IndexType -> bool) : forall i : Index r, Index (Rank.filter f i)
      := match r return forall i : Index r, Index (Rank.filter f i) with
         | 0%nat => fun _ => []
         | S r => fun idx => @filter r f (hd idx) ++' if f (tl idx) as ftlidx return Index (if ftlidx then _ else _) then [tl idx] else []
         end.

    Definition squeeze {r : Rank} (i : Index r) : Index (Rank.squeeze i)
      := filter (fun i => (i != 1)%core) i.

    Fixpoint unfilter {r : Rank} (f : IndexType -> bool) : forall {i : Index r}, Index (Rank.filter f i) -> Index r
      := match r return forall i : Index r, Index (Rank.filter f i) -> Index r with
         | 0%nat => fun _ idxs => idxs
         | S r
           => fun idx
              => if f (tl idx) as ftlidx return Index (_ +' if ftlidx then 1 else 0) -> Index (S r)
                 then fun idxs => @unfilter r f (hd idx) (hd idxs) ::' tl idxs
                 else fun idxs => @unfilter r f (hd idx) idxs ::' 0
         end%core.

    Definition unsqueeze {r : Rank} {i : Index r} : Index (Rank.squeeze i) -> Index r
      := unfilter (fun i => (i != 1)%core).

    Definition prod {r} : Index r -> IndexType
      := reduce mul 1%core.
  End ExtendedMake.

  Module Type ExtendedMakeSig (IndexType : ExtendedIndexType) := Nop <+ ExtendedMake IndexType.
End IndexGen.

Module Shape.
  Module ShapeType <: ExtendedIndexType.
    Definition t : Type := int.
    #[global] Strategy 100 [t].
    #[global] Bind Scope uint63_scope with t.
    Definition one : has_one t := _.
    Definition zero : has_zero t := _.
    Definition eqb : has_eqb t := _.
    Definition mul : has_mul t := _.
    Definition add : has_add t := _.
    Definition int_div : has_int_div t := _.
    Definition modulo : has_mod t := _.
    (* eta expand to get around COQBUG(https://github.com/coq/coq/issues/17663) *)
    Definition leb : has_leb t := fun x y => Uint63.leb x y.
    Definition ltb : has_ltb t := fun x y => Uint63.ltb x y.
  End ShapeType.

  Include IndexGen.ExtendedMake ShapeType.

  Module Export ShapeNotations.
    Declare Scope shape_scope.
    Delimit Scope shape_scope with shape.
    Bind Scope shape_scope with t.
    Bind Scope uint63_scope with IndexType.
    Notation "xs ::' x" := (snoc xs x) : shape_scope.
    Notation "[ ]" := nil : shape_scope.
    Notation "[ x ]" := (snoc nil x) : shape_scope.
    Notation "[ x ; y ; .. ; z ]" :=  (snoc .. (snoc (snoc nil x) y) .. z) : shape_scope.
    Notation "x :: xs" := (cons x xs) : shape_scope.
    Notation "s1 ++ s2" := (app s1 s2) : shape_scope.
    Notation "s1 ++' s2" := (app s1 s2) : shape_scope.
  End ShapeNotations.

  Definition broadcast2 {r} : Index r -> Index r -> Index r
    := map2 max.
  Definition broadcast3 {r} : Index r -> Index r -> Index r -> Index r
    := map3 (fun a b c => max (max a b) c).

  Definition reshape' {r} : Index r -> Z
    := Shape.reduce (fun z x => z * Uint63.to_Z x)%Z 1%Z.
  Definition reshape {r} (s : Index r) : Index 1
    := [Uint63.of_Z (reshape' s)].
End Shape.
Notation ShapeType := Shape.IndexType.
Notation Shape := Shape.Index.
Export Shape.ShapeNotations.
Export (hints) Shape.

Module RawIndex.
  Module RawIndexType <: ExtendedIndexType.
    Definition t : Type := int.
    #[global] Strategy 100 [t].
    #[global] Bind Scope uint63_scope with t.
    Definition one : has_one t := _.
    Definition zero : has_zero t := _.
    Definition eqb : has_eqb t := _.
    Definition mul : has_mul t := _.
    Definition add : has_add t := _.
    Definition int_div : has_int_div t := _.
    Definition modulo : has_mod t := _.
    (* eta expand to get around COQBUG(https://github.com/coq/coq/issues/17663) *)
    Definition leb : has_leb t := fun x y => Uint63.leb x y.
    Definition ltb : has_ltb t := fun x y => Uint63.ltb x y.
  End RawIndexType.

  Include IndexGen.ExtendedMake RawIndexType.

  Module Export RawIndexNotations.
    Declare Scope raw_index_scope.
    Delimit Scope raw_index_scope with raw_index.
    Bind Scope raw_index_scope with t.
    Bind Scope uint63_scope with IndexType.
    Notation "xs ::' x" := (snoc xs x) : raw_index_scope.
    Notation "[ ]" := nil : raw_index_scope.
    Notation "[ x ]" := (snoc nil x) : raw_index_scope.
    Notation "[ x ; y ; .. ; z ]" :=  (snoc .. (snoc (snoc nil x) y) .. z) : raw_index_scope.
    Notation "x :: xs" := (cons x xs) : raw_index_scope.
    Notation "s1 ++ s2" := (app s1 s2) : raw_index_scope.
    Notation "s1 ++' s2" := (app s1 s2) : raw_index_scope.
  End RawIndexNotations.

  Fixpoint reshape' {r} : Shape r -> Index r -> Z
    := match r with
       | 0%nat => fun s idx => 0
       | S r
         => fun s idx
            => Uint63.to_Z (tl idx) + @reshape' r (Shape.hd s) (hd idx) * Uint63.to_Z (Shape.tl s)
       end%Z%core%raw_index.

  Fixpoint unreshape' {r} : Shape r -> Z -> Index r
    := match r with
       | 0%nat => fun _ _ => []
       | S r
         => fun s idx
            => let tl_idx := idx mod (Uint63.to_Z (Shape.tl s)) in
               let hd_idx := idx // (Uint63.to_Z (Shape.tl s)) in
               @unreshape' r (Shape.hd s) hd_idx ::' Uint63.of_Z tl_idx
       end%Z%core%raw_index.

  Definition reshape {r} (s : Shape r) (idx : Index r) : Index 1 := [Uint63.of_Z (reshape' s idx)].
  Definition unreshape {r} (s : Shape r) (idx : Index 1) : Index r := unreshape' s (Uint63.to_Z (item idx)).

  Lemma unrereshape' {r} s idx : (match r with 0%nat => true | _ => idx <? s end)%core -> @unreshape' r s (@reshape' r s idx) = idx /\ (0 <= @reshape' r s idx < Shape.reshape' s)%Z.
  Proof.
    induction r; [ | rewrite expand_ltb ];
      cbv [Shape.reshape'] in *;
      cbn [Shape Index unreshape' reshape' Shape.reduce] in *;
      cbv [is_true Shape.hd Shape.tl snoc nil hd tl fst snd Classes.int_div Classes.add Classes.mul Classes.modulo Z_has_int_div] in *;
      repeat match goal with H : unit |- _ => destruct H | H : _ * _ |- _ => destruct H end; try (split; try reflexivity; lia);
      cbv [Classes.ltb RawIndexType.ltb Uint63.ltb] in *.
    all: rewrite Bool.andb_true_iff, Z_mod_plus_full, Uint63.ltb_spec.
    all: intros [H0 H1].
    repeat match goal with
           | [ |- context[to_Z ?x] ]
             => let lem := constr:(to_Z_bounded x) in
                let ty := type of lem in
                lazymatch goal with
                | [ _ : ty |- _ ] => fail
                | _ => idtac
                end;
                pose proof lem
           end.
    rewrite Z.mod_small, Z_div_plus_full, Z.div_small, Z.add_0_l, Uint63.of_to_Z by lia.
    destruct r;
      [ cbn [Shape Index unreshape' reshape' Shape.reduce] in *;
        cbv [is_true Shape.hd Shape.tl snoc nil hd tl fst snd Classes.int_div Classes.add Classes.mul Classes.modulo Z_has_int_div] in *;
        repeat match goal with H : unit |- _ => destruct H | H : _ * _ |- _ => destruct H end; split; try reflexivity; lia
      | ].
    specialize (IHr _ _ ltac:(eassumption)).
    destruct IHr as [IHr1 IHr2].
    rewrite IHr1; split; try reflexivity.
    nia.
  Qed.

  Lemma reunreshape' {r} s idx : (0 <= idx < Shape.reshape' s)%Z -> @reshape' r s (@unreshape' r s idx) = idx /\ (match r with 0%nat => true | _ => @unreshape' r s idx <? s end)%core.
  Proof.
    revert idx; induction r; intro idx; [ | rewrite expand_ltb ];
      cbv [Shape.reshape'] in *;
      cbn [Shape Index unreshape' reshape' Shape.reduce] in *;
      cbv [is_true Shape.hd Shape.tl snoc nil hd tl fst snd Classes.int_div Classes.add Classes.mul Classes.modulo Z_has_int_div] in *;
      repeat match goal with H : unit |- _ => destruct H | H : _ * _ |- _ => destruct H end; try (split; try reflexivity; lia);
      cbv [Classes.ltb RawIndexType.ltb Uint63.ltb] in *.
    all: rewrite Bool.andb_true_iff, Uint63.ltb_spec, !Uint63.of_Z_spec.
    intro H.
    repeat match goal with
           | [ |- context[to_Z ?x] ]
             => let lem := constr:(to_Z_bounded x) in
                let ty := type of lem in
                lazymatch goal with
                | [ _ : ty |- _ ] => fail
                | _ => idtac
                end;
                pose proof lem
           | [ |- context[(?x mod ?y)%Z] ]
             => let lem := constr:(Z.mod_pos_bound x y ltac:(lia)) in
                let ty := type of lem in
                lazymatch goal with
                | [ _ : ty |- _ ] => fail
                | _ => idtac
                end;
                pose proof lem
           | [ H : (0 <= ?idx < ?x * ?y)%Z |- _ ]
             => lazymatch goal with
                | [ _ : (0 < y)%Z |- _ ] => fail
                | _ => idtac
                end;
                assert (0 < x)%Z by nia;
                assert (0 < y)%Z by nia
           end.
    rewrite ?Z.mod_small by lia.
    match goal with
    | [ |- context[reshape' ?s (unreshape' ?s ?idx)] ]
      => specialize (IHr s idx)
    end.
    specialize (IHr ltac:(Z.to_euclidean_division_equations; nia)).
    destruct IHr as [IHr1 IHr2].
    rewrite IHr1; repeat split; try (now destruct r); try lia; [].
    Z.to_euclidean_division_equations; nia.
  Qed.
End RawIndex.
Notation RawIndexType := RawIndex.IndexType.
Notation RawIndex := RawIndex.Index.
Export RawIndex.RawIndexNotations.
Export (hints) RawIndex.

Module Index.
  Module IndexType <: ExtendedIndexType.
    Definition t : Type := int.
    #[global] Strategy 100 [t].
    #[global] Bind Scope sint63_scope with t.
    Definition one : has_one t := _.
    Definition zero : has_zero t := _.
    Definition eqb : has_eqb t := _.
    Definition mul : has_mul t := _.
    Definition add : has_add t := _.
    Definition int_div : has_int_div t := _.
    Definition modulo : has_mod t := _.
    (* eta expand to get around COQBUG(https://github.com/coq/coq/issues/17663) *)
    Definition leb : has_leb t := fun x y => Sint63.leb x y.
    Definition ltb : has_ltb t := fun x y => Sint63.ltb x y.
  End IndexType.

  Include IndexGen.ExtendedMake IndexType.
  Export IndexNotations.
  Bind Scope sint63_scope with IndexType.
End Index.
Notation IndexType := Index.IndexType.
Notation Index := Index.Index.
Export Index.IndexNotations.
Export (hints) Index.
Bind Scope sint63_scope with Index.IndexType.

(*
Definition tensor_of_rank@{a r} (A : Type@{a}) (r : Rank)
  := RawIndex@{r} r -> A.
(* we could have a separate universe for the shape, but since the shape argument is a phantom one anyway, we don't bother *)
Definition tensor@{a r} {r : Rank} (A : Type@{a}) (s : Shape@{r} r)
  := tensor_of_rank@{a r} A r.
*)
Monomorphic Definition tensor_of_rank (A : Type) (r : Rank) : Type
  := RawIndex r -> A.
Monomorphic Definition tensor {r : Rank} (A : Type) (s : Shape r) : Type
  := tensor_of_rank A r.

Monomorphic Definition tensor_dep {r A s} (P : A -> Type) (x : @tensor r A s)
  := forall i : RawIndex r, P (x i).

Definition tensor_undep {r A s P x} (t : @tensor_dep r A s (fun _ => P) x) : @tensor r P s
  := t.

Declare Scope tensor_scope.
Delimit Scope tensor_scope with tensor.
Declare Scope raw_tensor_scope.
Delimit Scope raw_tensor_scope with raw_tensor.
Bind Scope tensor_scope with tensor_of_rank.
Bind Scope tensor_scope with tensor.
Local Open Scope tensor_scope.

#[export] Instance empty_of_rank {A r} {default : pointed A} : pointed (tensor_of_rank A r)
  := fun _ => default.
#[export] Instance empty {r A} {default : pointed A} {s : Shape r} : pointed (tensor A s)
  := empty_of_rank.

#[export] Typeclasses Opaque Index.

Ltac get_shape val :=
  lazymatch type of val with
  | tensor _ ?shape => shape
  | list ?x
    => let len := (eval cbv in (Uint63.of_Z (Z.of_N (N.of_nat (List.length val))))) in
       let rest := lazymatch (eval hnf in val) with
                   | cons ?val _ => get_shape val
                   | ?val => fail 1 "Could not find cons in" val
                   end in
       constr:(Shape.cons len rest)
  | array ?x
    => let len := (eval cbv in (PArray.length val)) in
       let rest := let val := (eval cbv in (PArray.get val 0)) in
                   get_shape val in
       constr:(Shape.cons len rest)
  | _ => constr:(Shape.nil)
  end.
Notation shape_of x := (match x return _ with y => ltac:(let s := get_shape y in exact s) end) (only parsing).
Class compute_shape_of {A r} (x : A) := get_shape_of : Shape r.
#[global] Hint Extern 0 (compute_shape_of ?x) => let s := get_shape x in exact s : typeclass_instances.

Module PArray.
  Fixpoint concrete_tensor_of_rank (A : Type) (r : Rank) : Type
    := match r with
       | O => A
       | S r => concrete_tensor_of_rank (array A) r
       end.
  Definition concrete_tensor {r : Rank} (A : Type) (s : Shape r) : Type
    := concrete_tensor_of_rank A r.
  #[global] Strategy 100 [tensor_of_rank tensor concrete_tensor concrete_tensor_of_rank].

  Module Tensor.
    Fixpoint map {r A B} (f : A -> B) : forall {s}, @concrete_tensor r A s -> @concrete_tensor r B s
      := match r return forall {s}, @concrete_tensor r A s -> @concrete_tensor r B s with
         | O => fun _ => f
         | S r => fun s t => @map r _ _ (PArray.map f) (Shape.hd s) t
         end.
    Definition copy {r A s} t := @map r A A (fun x => x) s t.
  End Tensor.

  Fixpoint concretize {r : Rank} {A : Type} {default : pointed A} {struct r} : forall {s : Shape r} (t : tensor A s), concrete_tensor A s
    := match r with
       | 0%nat => fun _tt f => f tt
       | S r
         => fun '(s, len) f
            => concretize (r:=r) (A:=array A) (s:=s) (fun idxs => PArray.init_default len (fun idx => f (idxs, idx)))
       end.
  Fixpoint abstract_of_rank {r : Rank} {A : Type} {struct r}
    : concrete_tensor_of_rank A r -> tensor_of_rank A r
    := match r with
       | O => fun v _tt => v
       | S r => fun t '(idxs, idx) => PArray.get (@abstract_of_rank r (array A) t idxs) idx
       end.
  Definition abstract {r : Rank} {A : Type} {s : Shape r} : concrete_tensor A s -> tensor A s
    := abstract_of_rank.

  Notation to_tensor t := (@abstract _ _ (shape_of t%array) t%array) (only parsing).

  Lemma abstract_concretize {r A default} {s : Shape r} {t} {idxs : RawIndex r}
    (in_bounds : is_true (match r with O => true | _ => idxs <? s end)%core)
    (in_max_bounds : is_true (match r with O => true | _ => idxs <? RawIndex.repeat PArray.max_length r end)%core)
    : abstract (@concretize r A default s t) idxs = t idxs.
  Proof.
    cbv [abstract].
    revert A default idxs t in_bounds in_max_bounds; induction r as [|r IH]; cbn [abstract_of_rank concretize]; intros.
    { destruct idxs; reflexivity. }
    { cbv [is_true] in *.
      rewrite RawIndex.expand_ltb, Bool.andb_true_iff in in_bounds, in_max_bounds.
      destruct idxs, s.
      rewrite IH by first [ apply in_bounds | apply in_max_bounds ].
      rewrite PArray.get_init_default.
      rewrite RawIndex.tl_repeat in *.
      cbv [Classes.ltb Classes.leb RawIndex.RawIndexType.ltb RawIndex.tl] in *.
      cbn [RawIndex.hd RawIndex.tl RawIndex.repeat] in *.
      cbn in *.
      do 2 destruct PrimInt63.ltb; destruct in_bounds, in_max_bounds; try congruence; cbn.
      reflexivity. }
  Qed.

  Definition reabstract {r : Rank} {A s} (t_ : @tensor r A s) (t : @concrete_tensor r A s) : @tensor r A s
    := let t := abstract t in
       fun idxs
       => if ((idxs <? s) && (idxs <? RawIndex.repeat PArray.max_length r))%core%bool
          then t idxs
          else t_ idxs.

  Lemma reabstract_correct {r A} {s : Shape r} {t_} {t} {idxs : RawIndex r}
    : (forall
          (in_bounds : is_true (match r with O => true | _ => idxs <? s end)%core)
          (in_max_bounds : is_true (match r with O => true | _ => idxs <? RawIndex.repeat PArray.max_length r end)%core),
          abstract t idxs = t_ idxs)
      -> @reabstract r A s t_ t idxs = t_ idxs.
  Proof.
    cbv [reabstract].
    cbv [andb].
    repeat match goal with |- context[match ?x with _ => _ end] => destruct x eqn:? end.
    all: repeat match goal with H : context[match ?x with _ => _ end] |- _ => destruct x eqn:? end.
    all: auto.
    all: discriminate.
  Qed.

  Lemma reabstract_ext_correct {r A default} {s : Shape r} {t_ t}
    : t = @concretize r A default s t_ -> forall idxs, @reabstract r A s t_ t idxs = t_ idxs.
  Proof. intros; subst; apply reabstract_correct, abstract_concretize. Qed.

  Definition checkpoint {r : Rank} {A default s} t : @tensor r A s
    := let t_ := t in
       let t := @concretize r A default s t in
       reabstract t_ t.

  Lemma checkpoint_correct {r A default} {s : Shape r} {t} {idxs : RawIndex r}
    : @checkpoint r A default s t idxs = t idxs.
  Proof. cbv [checkpoint]; apply reabstract_ext_correct; reflexivity. Qed.
End PArray.

Module List.
  Fixpoint concrete_tensor_of_rank (A : Type) (r : Rank) : Type
    := match r with
       | O => A
       | S r => concrete_tensor_of_rank (list A) r
       end.
  Definition concrete_tensor {r : Rank} (A : Type) (s : Shape r) : Type
    := concrete_tensor_of_rank A r.
  #[global] Strategy 100 [tensor_of_rank tensor concrete_tensor concrete_tensor_of_rank].

  Module Tensor.
    Fixpoint map {r A B} (f : A -> B) : forall {s}, @concrete_tensor r A s -> @concrete_tensor r B s
      := match r return forall {s}, @concrete_tensor r A s -> @concrete_tensor r B s with
         | O => fun _ => f
         | S r => fun s t => @map r _ _ (List.map f) (Shape.hd s) t
         end.
    Definition copy {r A s} t := @map r A A (fun x => x) s t.
  End Tensor.

  Fixpoint concretize {r : Rank} {A : Type} {struct r} : forall {s : Shape r} (t : tensor A s), concrete_tensor A s
    := match r return forall {s : Shape r} (t : tensor A s), concrete_tensor A s with
       | 0%nat => fun _tt f => f tt
       | S r
         => fun '(s, len) f
            => concretize (r:=r) (A:=list A) (s:=s) (fun idxs => List.map (fun idx => f (idxs, Uint63.of_Z (Z.of_nat idx))) (List.seq 0 (Z.to_nat (Uint63.to_Z len))))
       end.
  Fixpoint abstract_of_rank {r : Rank} {A : Type} {default : pointed A} {struct r}
    : concrete_tensor_of_rank A r -> tensor_of_rank A r
    := match r return concrete_tensor_of_rank A r -> tensor_of_rank A r with
       | O => fun v _tt => v
       | S r => fun t '(idxs, idx) => nth_default default (@abstract_of_rank r (list A) _ t idxs) (Z.to_nat (Uint63.to_Z idx))
       end.
  Definition abstract {r : Rank} {A : Type} {default : pointed A} {s : Shape r} : concrete_tensor A s -> tensor A s
    := abstract_of_rank.

  Notation to_tensor t := (@abstract _ _ _ (shape_of t%list) t%list) (only parsing).

  Lemma abstract_concretize {r A} {default : pointed A} {s : Shape r} {t} {idxs : RawIndex r}
    (in_bounds : is_true (match r with O => true | _ => idxs <? s end)%core)
    : abstract (@concretize r A s t) idxs = t idxs.
  Proof.
    cbv [abstract].
    revert A default idxs t in_bounds; induction r as [|r IH]; cbn [abstract_of_rank concretize]; intros.
    { destruct idxs; reflexivity. }
    { cbv [is_true] in *.
      rewrite RawIndex.expand_ltb, Bool.andb_true_iff in in_bounds.
      destruct idxs as [idxs idx], s as [ss s].
      rewrite IH by first [ apply in_bounds | apply in_max_bounds ].
      cbv [nth_default].
      rewrite nth_error_map.
      rewrite List.nth_error_seq.
      cbv [Classes.ltb Classes.leb RawIndex.RawIndexType.ltb RawIndex.tl] in *.
      cbn in in_bounds.
      rewrite Uint63.ltb_spec in in_bounds.
      destruct (Uint63.to_Z_bounded idx).
      destruct (Uint63.to_Z_bounded s).
      destruct Nat.ltb eqn:H'; cbn [option_map].
      1:rewrite Nat.ltb_lt, <- Z2Nat.inj_lt in H' by assumption.
      2:rewrite Nat.ltb_ge, <- Z2Nat.inj_le in H' by assumption.
      1: rewrite Nat.add_0_l, Z2Nat.id, of_to_Z by assumption.
      all: first [ reflexivity | lia ]. }
  Qed.

  Definition reabstract {r : Rank} {A default s} (t_ : @tensor r A s) (t : @concrete_tensor r A s) : @tensor r A s
    := let t := @abstract r A default s t in
       fun idxs
       => if (idxs <? s)%core
          then t idxs
          else t_ idxs.

  Lemma reabstract_correct {r A default} {s : Shape r} {t_} {t} {idxs : RawIndex r}
    : (forall
          (in_bounds : is_true (match r with O => true | _ => idxs <? s end)%core),
          abstract t idxs = t_ idxs)
      -> @reabstract r A default s t_ t idxs = t_ idxs.
  Proof.
    cbv [reabstract].
    repeat match goal with |- context[match ?x with _ => _ end] => destruct x eqn:? end.
    all: auto.
  Qed.

  Lemma reabstract_ext_correct {r A default} {s : Shape r} {t_ t}
    : t = @concretize r A s t_ -> forall idxs, @reabstract r A default s t_ t idxs = t_ idxs.
  Proof. intros; subst; apply reabstract_correct, abstract_concretize. Qed.

  Definition checkpoint {r : Rank} {A default s} t : @tensor r A s
    := let t_ := t in
       let t := @concretize r A s t in
       @reabstract r A default s t_ t.

  Lemma checkpoint_correct {r A default} {s : Shape r} {t} {idxs : RawIndex r}
    : @checkpoint r A default s t idxs = t idxs.
  Proof. cbv [checkpoint]; apply reabstract_ext_correct; reflexivity. Qed.
End List.

Definition adjust_index_for (s : ShapeType) : Index.IndexType -> RawIndex.IndexType
  := fun i => i mod s.

Definition adjust_indices_for {r} (s : Shape r) : Index r -> RawIndex r
  := Index.map2 adjust_index_for s.

Definition with_shape {r A} (s : Shape r) : @Shape.curriedT r A -> A
  := fun f => Shape.uncurry f s.

Notation of_array ls := (PArray.to_tensor ls) (only parsing).
Notation of_list ls := (List.to_tensor ls) (only parsing).

Definition repeat' {r A} (x : A) {s : Shape r} : tensor A s
  := fun _ => x.
Definition ones {r} {A} {one : has_one A} (s : Shape r) : tensor A s
  := repeat' one.
Definition zeros {r} {A} {zero : has_zero A} (s : Shape r) : tensor A s
  := repeat' zero.

Definition raw_get {r A} {s : Shape r} (t : tensor A s) (idxs : RawIndex r) : A
  := t idxs.
Definition get {r A} {s : Shape r} (t : tensor A s) (idxs : Index r) : A
  := raw_get t (adjust_indices_for s idxs).
Definition item {A} (t : tensor A []) : A := raw_get t tt.

Notation "x .[ y ]" := (get x y) : tensor_scope.
Notation "x .[ y ]" := (raw_get x y) : raw_tensor_scope.

Definition curried_raw_get {r A} {s : Shape r} (t : tensor A s) : @RawIndex.curriedT r A
  := RawIndex.curry (fun idxs => raw_get t idxs).
Definition curried_get {r A} {s : Shape r} (t : tensor A s) : @Index.curriedT r A
  := Index.curry (fun idxs => get t idxs).

Definition map {r A B} {s : Shape r} (f : A -> B) (t : tensor A s) : tensor B s
  := fun i => f (t i).
Definition map2 {r A B C} {sA sB : Shape r} (f : A -> B -> C) (tA : tensor A sA) (tB : tensor B sB) : tensor C (Shape.broadcast2 sA sB)
  := fun i => f (tA i) (tB i).
Definition map3 {r A B C D} {sA sB sC : Shape r} (f : A -> B -> C -> D) (tA : tensor A sA) (tB : tensor B sB) (tC : tensor C sC) : tensor D (Shape.broadcast3 sA sB sC)
  := fun i => f (tA i) (tB i) (tC i).

Definition map_dep {r A B} {s : Shape r} (f : forall a : A, B a) (t : tensor A s) : tensor_dep B t
  := fun i => f (t i).


Definition where_ {r A} {sA : Shape r} {sB : Shape r} {sC : Shape r} (condition : tensor bool sA) (input : tensor A sB) (other : tensor A sC) : tensor A (Shape.broadcast3 sA sB sC)
  := map3 Bool.where_ condition input other.

(* TODO: autobroadcast initial *)
#[export] Instance tensor_add {r} {sA sB : Shape r} {A B C} {addA : has_add_with A B C} : has_add_with (tensor A sA) (tensor B sB) (tensor C (Shape.broadcast2 sA sB)) := map2 add.
#[export] Instance tensor_sub {r} {sA sB : Shape r} {A B C} {subA : has_sub_with A B C} : has_sub_with (tensor A sA) (tensor B sB) (tensor C (Shape.broadcast2 sA sB)) := map2 sub.
#[export] Instance tensor_mul {r} {sA sB : Shape r} {A B C} {mulA : has_mul_with A B C} : has_mul_with (tensor A sA) (tensor B sB) (tensor C (Shape.broadcast2 sA sB)) := map2 mul.
#[export] Instance tensor_div_by {r} {sA sB : Shape r} {A B C} {div_byAB : has_div_by A B C} : has_div_by (tensor A sA) (tensor B sB) (tensor C (Shape.broadcast2 sA sB)) := map2 div.
#[export] Instance tensor_sqrt {r} {s : Shape r} {A} {sqrtA : has_sqrt A} : has_sqrt (tensor A s) := map sqrt.
#[export] Instance tensor_opp {r} {s : Shape r} {A} {oppA : has_opp A} : has_opp (tensor A s) := map opp.
#[export] Instance add'1 {r} {s : Shape r} {a b} {A B C} {addA : has_add_with A B C} : has_add_with (tensor A (s ::' a)) (tensor B (s ::' b)) (tensor C (s ::' max a b)) | 10 := tensor_add.
#[export] Instance sub'1 {r} {s : Shape r} {a b} {A B C} {subA : has_sub_with A B C} : has_sub_with (tensor A (s ::' a)) (tensor B (s ::' b)) (tensor C (s ::' max a b)) | 10 := tensor_sub.
#[export] Instance mul'1 {r} {s : Shape r} {a b} {A B C} {mulA : has_mul_with A B C} : has_mul_with (tensor A (s ::' a)) (tensor B (s ::' b)) (tensor C (s ::' max a b)) | 10 := tensor_mul.
#[export] Instance div_by'1 {r} {s : Shape r} {a b} {A B C} {div_byA : has_div_by A B C} : has_div_by (tensor A (s ::' a)) (tensor B (s ::' b)) (tensor C (s ::' max a b)) | 10 := tensor_div_by.
#[export] Instance add'1s_r {r} {s : Shape r} {A B C} {addA : has_add_with A B C} : has_add_with (tensor A s) (tensor B (@Shape.ones r)) (tensor C s) | 10 := tensor_add.
#[export] Instance add'1s_l {r} {s : Shape r} {A B C} {addA : has_add_with A B C} : has_add_with (tensor A (@Shape.ones r)) (tensor B s) (tensor C s) | 10 := tensor_add.
#[export] Instance sub'1s_r {r} {s : Shape r} {A B C} {subA : has_sub_with A B C} : has_sub_with (tensor A s) (tensor B (@Shape.ones r)) (tensor C s) | 10 := tensor_sub.
#[export] Instance sub'1s_l {r} {s : Shape r} {A B C} {subA : has_sub_with A B C} : has_sub_with (tensor A (@Shape.ones r)) (tensor B s) (tensor C s) | 10 := tensor_sub.
#[export] Instance mul'1s_r {r} {s : Shape r} {A B C} {mulA : has_mul_with A B C} : has_mul_with (tensor A s) (tensor B (@Shape.ones r)) (tensor C s) | 10 := tensor_mul.
#[export] Instance mul'1s_l {r} {s : Shape r} {A B C} {mulA : has_mul_with A B C} : has_mul_with (tensor A (@Shape.ones r)) (tensor B s) (tensor C s) | 10 := tensor_mul.
#[export] Instance div_by'1s_r {r} {s : Shape r} {A B C} {div_byA : has_div_by A B C} : has_div_by (tensor A s) (tensor B (@Shape.ones r)) (tensor C s) | 10 := tensor_div_by.
#[export] Instance div_by'1s_l {r} {s : Shape r} {A B C} {div_byA : has_div_by A B C} : has_div_by (tensor A (@Shape.ones r)) (tensor B s) (tensor C s) | 10 := tensor_div_by.
#[export] Instance add'1s_r'1_same {r} {s : Shape r} {a} {A B C} {addA : has_add_with A B C} : has_add_with (tensor A (s ::' a)) (tensor B (@Shape.ones r ::' a)) (tensor C (s ::' a)) | 10 := tensor_add.
#[export] Instance add'1s_l'1_same {r} {s : Shape r} {a} {A B C} {addA : has_add_with A B C} : has_add_with (tensor A (@Shape.ones r ::' a)) (tensor B (s ::' a)) (tensor C (s ::' a)) | 10 := tensor_add.
#[export] Instance sub'1s_r'1_same {r} {s : Shape r} {a} {A B C} {subA : has_sub_with A B C} : has_sub_with (tensor A (s ::' a)) (tensor B (@Shape.ones r ::' a)) (tensor C (s ::' a)) | 10 := tensor_sub.
#[export] Instance sub'1s_l'1_same {r} {s : Shape r} {a} {A B C} {subA : has_sub_with A B C} : has_sub_with (tensor A (@Shape.ones r ::' a)) (tensor B (s ::' a)) (tensor C (s ::' a)) | 10 := tensor_sub.
#[export] Instance mul'1s_r'1_same {r} {s : Shape r} {a} {A B C} {mulA : has_mul_with A B C} : has_mul_with (tensor A (s ::' a)) (tensor B (@Shape.ones r ::' a)) (tensor C (s ::' a)) | 10 := tensor_mul.
#[export] Instance mul'1s_l'1_same {r} {s : Shape r} {a} {A B C} {mulA : has_mul_with A B C} : has_mul_with (tensor A (@Shape.ones r ::' a)) (tensor B (s ::' a)) (tensor C (s ::' a)) | 10 := tensor_mul.
#[export] Instance div_by'1s_r'1_same {r} {s : Shape r} {a} {A B C} {div_byA : has_div_by A B C} : has_div_by (tensor A (s ::' a)) (tensor B (@Shape.ones r ::' a)) (tensor C (s ::' a)) | 10 := tensor_div_by.
#[export] Instance div_by'1s_l'1_same {r} {s : Shape r} {a} {A B C} {div_byA : has_div_by A B C} : has_div_by (tensor A (@Shape.ones r ::' a)) (tensor B (s ::' a)) (tensor C (s ::' a)) | 10 := tensor_div_by.
#[export] Instance add'1s_r'1_same_app {r r'} {s : Shape r} {s' : Shape r'} {A B C} {addA : has_add_with A B C} : has_add_with (tensor A (s ++' s')) (tensor B (@Shape.ones r ++' s')) (tensor C (s ++' s')) | 10 := tensor_add.
#[export] Instance add'1s_l'1_same_app {r r'} {s : Shape r} {s' : Shape r'} {A B C} {addA : has_add_with A B C} : has_add_with (tensor A (@Shape.ones r ++' s')) (tensor B (s ++' s')) (tensor C (s ++' s')) | 10 := tensor_add.
#[export] Instance sub'1s_r'1_same_app {r r'} {s : Shape r} {s' : Shape r'} {A B C} {subA : has_sub_with A B C} : has_sub_with (tensor A (s ++' s')) (tensor B (@Shape.ones r ++' s')) (tensor C (s ++' s')) | 10 := tensor_sub.
#[export] Instance sub'1s_l'1_same_app {r r'} {s : Shape r} {s' : Shape r'} {A B C} {subA : has_sub_with A B C} : has_sub_with (tensor A (@Shape.ones r ++' s')) (tensor B (s ++' s')) (tensor C (s ++' s')) | 10 := tensor_sub.
#[export] Instance mul'1s_r'1_same_app {r r'} {s : Shape r} {s' : Shape r'} {A B C} {mulA : has_mul_with A B C} : has_mul_with (tensor A (s ++' s')) (tensor B (@Shape.ones r ++' s')) (tensor C (s ++' s')) | 10 := tensor_mul.
#[export] Instance mul'1s_l'1_same_app {r r'} {s : Shape r} {s' : Shape r'} {A B C} {mulA : has_mul_with A B C} : has_mul_with (tensor A (@Shape.ones r ++' s')) (tensor B (s ++' s')) (tensor C (s ++' s')) | 10 := tensor_mul.
#[export] Instance div_by'1s_r'1_same_app {r r'} {s : Shape r} {s' : Shape r'} {A B C} {div_byA : has_div_by A B C} : has_div_by (tensor A (s ++' s')) (tensor B (@Shape.ones r ++' s')) (tensor C (s ++' s')) | 10 := tensor_div_by.
#[export] Instance div_by'1s_l'1_same_app {r r'} {s : Shape r} {s' : Shape r'} {A B C} {div_byA : has_div_by A B C} : has_div_by (tensor A (@Shape.ones r ++' s')) (tensor B (s ++' s')) (tensor C (s ++' s')) | 10 := tensor_div_by.

(*
Fixpoint extend_app_nil_l {P : Size -> Type} {s : Size} : P s -> P ([] ++' s)
  := match s with
     | [] => fun x => x
     | s ::' _ => @extend_app_nil_l (fun s => P (s ::' _)) s
     end.
Fixpoint contract_app_nil_l {P : Size -> Type} {s : Size} : P ([] ++' s) -> P s
  := match s with
     | [] => fun x => x
     | s ::' _ => @contract_app_nil_l (fun s => P (s ::' _)) s
     end.
 *)

Definition reshape_app_split' {A r1 r2 s1 s2} : @tensor (r1 +' r2) A (s1 ++' s2) -> tensor (tensor A s2) s1
  := RawIndex.curry_radd.
Definition reshape_app_combine' {A r1 r2 s1 s2} : tensor (tensor A s2) s1 -> @tensor (r1 +' r2) A (s1 ++' s2)
  := RawIndex.uncurry_radd.
(* infer s1 s2 from the conclusion *)
#[global] Arguments reshape_app_combine' A & r1 r2 s1 s2 _.
#[global] Arguments reshape_app_split' A & r1 r2 s1 s2 _.
Definition reshape_app_split {A r1 r2 s1 s2} : @tensor (r1 +' r2) A (s1 ++' s2) -> tensor (tensor A s2) s1
  := reshape_app_split'.
Definition reshape_app_combine {A r1 r2 s1 s2} : tensor (tensor A s2) s1 -> @tensor (r1 +' r2) A (s1 ++' s2)
  := reshape_app_combine'.
Definition reshape_snoc_split {A r s1 s2} : @tensor (r +' 1) A (s1 ::' s2) -> tensor (tensor A [s2]) s1
  := RawIndex.curry_radd.
Definition reshape_snoc_combine {A r s1 s2} : tensor (tensor A [s2]) s1 -> @tensor (r +' 1) A (s1 ::' s2)
  := RawIndex.uncurry_radd.
Definition uncurry {r A} {s : Shape r} : @RawIndex.curriedT r A -> tensor A s
  := RawIndex.uncurry.
Definition curry {r A} {s : Shape r} : tensor A s -> @RawIndex.curriedT r A
  := RawIndex.curry.

Definition map' {ra1 ra2 rb A B} {sa1 : Shape ra1} {sa2 : Shape ra2} {sb : Shape rb} (f : tensor A sa2 -> tensor B sb) (t : tensor A (sa1 ++' sa2)) : tensor B (sa1 ++' sb)
  := reshape_app_combine (map f (reshape_app_split t)).
Definition map2' {ri1 ri2 ro A B C} {sA1 sB1 : Shape ri1} {sA2 sB2 : Shape ri2} {so : Shape ro} (f : tensor A sA2 -> tensor B sB2 -> tensor C so) (tA : tensor A (sA1 ++' sA2)) (tB : tensor B (sB1 ++' sB2)) : tensor C (Shape.broadcast2 sA1 sB1 ++' so)
  := reshape_app_combine (map2 f (reshape_app_split tA) (reshape_app_split tB)).

(*
Definition reshape_S_fun_combine {I A} {r : Rank} : (I -> tensor_fun_of_rank I A r) -> tensor_fun_of_rank I A (1 +' r)
  := match reshape_app_combine_gen (r1:=1) (r2:=r) with x => x end.
Definition reshape_S_fun_split {I A} {r : Rank} : tensor_fun_of_rank I A (1 +' r) -> (I -> tensor_fun_of_rank I A r)
  := match reshape_app_split_gen (r1:=1) (r2:=r) with x => x end.
*)
(*
Require Import Program . Obligation Tactic := cbn; intros.
Fixpoint broadcast_map_ {A B} {s1 s2 : Size} {keepdim : with_default bool false} (f : A -> tensor_of_shape B s2) {struct s1} : tensor_of_shape A s1 -> tensor_of_shape (tensor_of_shape B (s1 ++' (if keepdim then [1] else []) ++' s2) s1.
refine match s1, keepdim return tensor_of_shape A s1 -> tensor_of_shape B (s1 ++' (if keepdim then [1] else []) ++' s2) with
     | [], true => fun x => reshape_app_combine (s1:=[1]) (PArray.make 1 (f x))
     | [], false => fun x => reshape_app_combine (s1:=[]) (f x)
     | s1 ::' _, keepdim
       => fun x => _ (*(broadcast_map (keepdim:=keepdim) (s1:=s1)) (* _(*PArray.map f*))*)*)
       end; cbn in *.
epose (@broadcast_map _ _ s1 _ keepdim _ x).
epose (@broadcast_map _ _ s1 _ keepdim (fun a => reshape_app_combine (s1:=[1])).
Next Obligation.
  pose (
 pose (broa

Fixpoint extended_broadcast_map {A B} {s1 s1' s2 : Size} (f : tensor_of_shape A s1' -> tensor_of_shape B s2) {struct s1} : tensor_of_shape A (s1 ++ s1') -> tensor_of_shape B (s1 ++ s2)
  := match s1 with
     | [] => f
     | s :: s1
       => PArray.map (extended_broadcast_map f)
     end.
 *)

(*
Definition broadcast_m1 {A s} n : tensor_of_shape A s -> tensor_of_shape A (s ::' n)
  := tensor_map (PArray.make n).
Definition broadcast_0 {A s} n : tensor_of_shape A s -> tensor_of_shape A ([n] ++' s)
  := fun x => reshape_app_combine (PArray.make n x).
#[global] Arguments broadcast_m1 A & s n _.
#[global] Arguments broadcast_0 A & s n _.
Definition slice_none_m1 {A s} : tensor_of_shape A s -> tensor_of_shape A (s ::' 1)
  := broadcast_m1 1.
Definition slice_none_0 {A s} : tensor_of_shape A s -> tensor_of_shape A ([1] ++' s)
  := broadcast_0 1.
*)

Definition broadcast' {A} (x : A) {r : Rank} : tensor A (@Shape.ones r)
  := repeat' x.
Definition broadcast {r A} {s : Shape r} (x : tensor A s) {r' : Rank} : tensor A (@Shape.ones r' ++' s)
  := reshape_app_combine (broadcast' x).
Definition repeat {r A} {s : Shape r} (x : tensor A s) {r' : Rank} (s' : Shape r') : tensor A (s' ++' s)
  := reshape_app_combine (repeat' x (s:=s')).

Definition keepdim_gen {r} {s : Shape r} {A B} (f : A -> tensor B s) : A -> tensor B ([1] ++' s)
  := fun a => broadcast (f a).
Definition keepdim {A B} (f : A -> B) : A -> tensor B [1] := keepdim_gen (s:=[]) (fun a 'tt => f a).
#[local] Notation keepdimf := keepdim (only parsing).

Definition reduce_axis_m1' {r A B} {s1 : Shape r} {s2}
  (reduction : forall (start stop step : RawIndexType), (RawIndexType -> A) -> B)
  (t : tensor A (s1 ::' s2))
  : tensor B s1
  := map (fun v => reduction 0 s2 1 (fun i => raw_get v [i])) (reshape_snoc_split t).

Definition reduce_axis_m1 {r A B} {s1 : Shape r} {s2} {keepdim : with_default "keepdim" bool false}
  (reduction : forall (start stop step : RawIndexType), (RawIndexType -> A) -> B)
  : tensor A (s1 ::' s2) -> tensor B (s1 ++' if keepdim return Shape (if keepdim then _ else _) then [1] else [])
  := if keepdim
          return tensor A (s1 ::' s2) -> tensor B (s1 ++' if keepdim return Shape (if keepdim then _ else _) then [1] else [])
     then fun t idxs => reduce_axis_m1' reduction t (RawIndex.hd idxs)
     else reduce_axis_m1' reduction.

Definition softmax_dim_m1 {r A B C} {addB : has_add B} {expA : has_exp_to A B} {zeroB : has_zero B} {divB : has_div_by B B C} {s0 : Shape r} {s'} (s:=(s0 ::' s')%shape) (t : tensor A s) : tensor C s
  := (let exp_t : tensor B s := map exp t in
      let sum_exp_t : tensor B s := reduce_axis_m1 (keepdim:=true) sum exp_t in
      exp_t / sum_exp_t)%core.

Definition log_softmax_dim_m1 {r A B C D} {addB : has_add B} {lnA : has_ln_to B C} {expA : has_exp_to A B} {zeroB : has_zero B} {divB : has_div_by A C D} {s0 : Shape r} {s'} (s:=(s0 ::' s')%shape) (t : tensor A s) : tensor D s
  := (let exp_t : tensor B s := map exp t in
      let sum_exp_t : tensor B s := reduce_axis_m1 (keepdim:=true) sum exp_t in
      let ln_sum_exp_t : tensor C s := map ln sum_exp_t in
      t / ln_sum_exp_t)%core.

Definition unsqueeze_dim_m1 {A r} {s : Shape r} (t : tensor A s) : tensor A (s ::' 1)
  := fun idxs => raw_get t (RawIndex.hd idxs).

Definition gather_dim_m1 {A r} {ssinput ssindex : Shape r} {sinput' sindex'}
  (sinput := (ssinput ::' sinput')%shape) (sindex := (ssindex ::' sindex')%shape)
  (input : tensor A sinput)
  (index : tensor IndexType sindex)
  : tensor A sindex
  := fun idx => raw_get input (RawIndex.hd idx ::' adjust_index_for sinput' (raw_get index idx))%raw_index.

Definition squeeze {r A} {s : Shape r} (t : tensor A s) : tensor A (Shape.squeeze s)
  := fun idx => raw_get t (RawIndex.unsqueeze idx).

Definition reshape_m1 {A r} {s : Shape r} (t : tensor A s) : tensor A (Shape.reshape s)
  := fun idx => raw_get t (RawIndex.unreshape s idx).
Definition unreshape_m1 {A r} {s : Shape r} (t : tensor A (Shape.reshape s)) : tensor A s
  := fun idx => raw_get t (RawIndex.reshape s idx).
(*
Definition reshape {A r1 r2} {s1 : Shape r1} (t : tensor A s1) (s2 : Shape r2) : tensor A s2
  := unreshape_m1 (reshape_m1 t : tensor A (Shape.reshape s2)).
 *)

Definition to_bool {A} {zero : has_zero A} {eqb : has_eqb A} {r} {s : Shape r} (xs : tensor A s) : tensor bool s
  := map (fun x => x ≠? 0)%core xs.

Definition of_bool {A} {zero : has_zero A} {one : has_one A} {r} {s : Shape r} (xs : tensor bool s) : tensor A s
  := map (fun x:bool => if x then 1 else 0)%core xs.

Definition mean {r A} {s : Shape r} {B C} {zero : has_zero A} {add : has_add A} {div_by : has_div_by A B C} {coer : has_coer Z B} (t : tensor A s) : tensor C []
  := reduce_axis_m1 Reduction.mean (reshape_m1 t).
(*
Definition arange {A B} {START STOP STEP IDX} {oneA : has_one A} {zeroStart : has_zero START} {oneStep : has_one STEP} {sub : has_sub_with STOP START A} {subA : has_sub A} {div : has_int_div_by A STEP B} {coerZ : has_coer B Z} {coerIDX : has_coer int IDX} {add : has_add_with START C D} {mul : has_mul_with STEP IDX C}
  {start : with_default "start" START 0%core} (stop : STOP) {step : with_default "step" STEP 1%core}
  : tensor int [(1 + Uint63.of_Z (((stop - start) - 1) // step))%core%uint63]
  := fun idx => let idx := RawIndex.item idx in
                (start + idx * step)%uint63.
*)
Definition arange {start : with_default "start" int 0%uint63} (stop : int) {step : with_default "step" int 1%uint63}
  : tensor int [(1 + (stop - start - 1) / step)%uint63]
  := fun idx => let idx := RawIndex.item idx in
                (start + idx * step)%uint63.

#[global] Arguments arange (_ _ _)%uint63.
#[global] Arguments arange {_} _ {_}, _ _ {_}, _ _ _.

(* TODO: nary *)
Definition tupleify {A B s1 s2} (t1 : tensor A [s1]) (t2 : tensor B [s2]) : tensor (A * B) [s1; s2]
  := fun '((tt, a), b) => (raw_get t1 [a], raw_get t2 [b]).
Definition cartesian_prod {A s1 s2} (t1 : tensor A [s1]) (t2 : tensor A [s2]) : tensor A [s1 * s2; 2]
  := fun '((tt, idx), tuple_idx)
     => let '(a, b) := raw_get (reshape_m1 (tupleify t1 t2)) [idx] in
        nth_default a [a; b] (Z.to_nat (Uint63.to_Z (tuple_idx mod 2))).

(** Quoting https://pytorch.org/docs/stable/generated/torch.tril.html

torch.tril(input, diagonal=0, *, out=None) → Tensor

Returns the lower triangular part of the matrix (2-D tensor) or batch
of matrices [input], the other elements of the result tensor [out] are
set to 0.

The lower triangular part of the matrix is defined as the elements on
and below the diagonal.

The argument [diagonal] controls which diagonal to consider. If
[diagonal = 0], all elements on and below the main diagonal are
retained. A positive value includes just as many diagonals above the
main diagonal, and similarly a negative value excludes just as many
diagonals below the main diagonal. The main diagonal are the set of
indices {(i,i)} for i ∈ [0,min{d₁,d₂}−1] where d₁,d₂ are the
dimensions of the matrix. *)
Definition tril {A} {zero : has_zero A} {rnk} {s : Shape rnk} {r c}
  {diagonal : with_default "diagonal" int 0%int63} (input : tensor A (s ++' [r; c]))
  : tensor A (s ++' [r; c])
  := fun '(((_, i), j) as idxs)
     => if ((0 ≤? i) && (i <? r) && (Sint63.max 0 (1 + i + diagonal) ≤? j) && (j <? c))%bool
        then 0%core
        else input idxs.
#[global] Arguments tril {A%type_scope zero rnk%nat s%shape} {r c}%uint63 {diagonal}%sint63 input%tensor.
(** Quoting https://pytorch.org/docs/stable/generated/torch.triu.html

torch.triu(input, diagonal=0, *, out=None) → Tensor

Returns the upper triangular part of the matrix (2-D tensor) or batch
of matrices [input], the other elements of the result tensor [out] are
set to 0.

The upper triangular part of the matrix is defined as the elements on
and above the diagonal.

The argument [diagonal] controls which diagonal to consider. If
[diagonal = 0], all elements on and above the main diagonal are
retained. A positive value excludes just as many diagonals above the
main diagonal, and similarly a negative value includes just as many
diagonals below the main diagonal. The main diagonal are the set of
indices {(i,i)} for i ∈ [0,min{d₁,d₂}−1] where d₁,d₂ are the
dimensions of the matrix. *)
Definition triu {A} {zero : has_zero A} {rnk} {s : Shape rnk} {r c}
  {diagonal : with_default "diagonal" int 0%int63} (input : tensor A (s ++' [r; c]))
  : tensor A (s ++' [r; c])
  := fun '(((_, i), j) as idxs)
     => if ((0 ≤? i) && (i <? r) && (0 ≤? j) && (j <? Sint63.max 0 (i + diagonal)))%bool
        then 0%core
        else input idxs.
#[global] Arguments triu {A%type_scope zero rnk%nat s%shape} {r c}%uint63 {diagonal}%sint63 input%tensor.
