From Coq Require Import Relations.Relation_Definitions.
From NeuralNetInterp.Util.Relations Require Import Relation_Definitions.Hetero.
#[local] Set Implicit Arguments.

Definition relation (F : Type -> Type)
  := forall A B, Hetero.relation A B -> Hetero.relation (F A) (F B).
Definition relation2 (F : Type -> Type -> Type)
  := forall A B, Hetero.relation A B -> forall A' B', Hetero.relation A' B' -> Hetero.relation (F A A') (F B B').
Definition relation3 (F : Type -> Type -> Type -> Type)
  := forall A B, Hetero.relation A B -> forall A' B', Hetero.relation A' B' -> forall A'' B'', Hetero.relation A'' B'' -> Hetero.relation (F A A' A'') (F B B' B'').
Section Relation_Definition.

  Variable F : Type -> Type.


  (*
  Variable R : relation.

  Section General_Properties_of_Relations.

    Definition reflexive : Prop := forall A RA, @reflexive A RA -> forall x, R RA x x.
    Definition transitive : Prop := forall A RA, @transitive A RA -> forall x, R RA x x.
    Definition transitive : Prop := forall (Ri:Relation_Definitions.relation I) i j k (x:A i) (y:A j) (z:A k), (Ri i j -> Ri j k -> Ri i k) -> R Ri x y -> R Ri y z -> R Ri x z.
    Definition symmetric : Prop := forall (Ri:Relation_Definitions.relation I) i j (x:A i) (y:A j), (Ri i j -> Ri j i) -> R Ri x y -> R Ri y x.
    Definition antisymmetric : Prop := forall (Ri:Relation_Definitions.relation I) i (x y:A i), R Ri x y -> R Ri y x -> x = y.

    (* for compatibility with Equivalence in  ../PROGRAMS/ALG/  *)
    Definition equiv := reflexive /\ transitive /\ symmetric.

  End General_Properties_of_Relations.



  Section Sets_of_Relations.

    Record preorder : Prop :=
      { preord_refl : reflexive; preord_trans : transitive}.

    Record order : Prop :=
      { ord_refl : reflexive;
	ord_trans : transitive;
	ord_antisym : antisymmetric}.

    Record equivalence : Prop :=
      { equiv_refl : reflexive;
	equiv_trans : transitive;
	equiv_sym : symmetric}.

    Record PER : Prop :=  {per_sym : symmetric; per_trans : transitive}.

  End Sets_of_Relations.


  Section Relations_of_Relations.

    Definition inclusion (R1 R2:relation) : Prop :=
      forall Ri i j x y, R1 Ri i j x y -> R2 Ri i j x y.

    Definition same_relation (R1 R2:relation) : Prop :=
      inclusion R1 R2 /\ inclusion R2 R1.
(*
    Definition commut (R1 R2:relation) : Prop :=
      forall i j (x:A i) (y:A j),
	R1 _ _ y x -> forall k (z:A k), R2 _ _ z y ->  exists2 y' : A, R2 y' x & R1 z y'.
*)
  End Relations_of_Relations.

*)
End Relation_Definition.
(*
#[export]
Hint Unfold reflexive transitive antisymmetric symmetric: sets.

#[export]
Hint Resolve Build_preorder Build_order Build_equivalence Build_PER
  preord_refl preord_trans ord_refl ord_trans ord_antisym equiv_refl
  equiv_trans equiv_sym per_sym per_trans: sets.

#[export]
Hint Unfold inclusion same_relation commut: sets.
*)
