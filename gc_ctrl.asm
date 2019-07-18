; Процедуры (C примитивы) управления сборщиком мусора.


C_primitive caml_gc_stat
end C_primitive


C_primitive caml_gc_quick_stat
end C_primitive


C_primitive caml_gc_minor_words
end C_primitive


C_primitive caml_gc_counters
end C_primitive


C_primitive caml_gc_huge_fallback_count
end C_primitive


C_primitive caml_gc_get
end C_primitive


C_primitive caml_gc_set
end C_primitive


caml_gc_minor := caml_gc_full_major


C_primitive caml_gc_major
end C_primitive


; EDI - не используется.
C_primitive caml_gc_full_major
if HEAP_GC
;	env может хранить ссылку на блок, который необходимо сохранить.
	push	env
	mov	alloc_small_ptr, alloc_small_ptr_backup
	call	heap_mark_compact_gc
	mov	alloc_small_ptr_backup, alloc_small_ptr
	pop	env
end if
	ret
end C_primitive


C_primitive caml_gc_major_slice
end C_primitive


caml_gc_compaction := caml_gc_full_major


C_primitive caml_get_minor_free
end C_primitive


C_primitive caml_get_major_bucket
end C_primitive


C_primitive caml_get_major_credit
end C_primitive


C_primitive caml_runtime_variant
end C_primitive


C_primitive caml_runtime_parameters
end C_primitive


C_primitive caml_ml_enable_runtime_warnings
end C_primitive


C_primitive caml_ml_runtime_warnings_enabled
end C_primitive
