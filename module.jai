#module_parameters(ENTITY_HEADER_TYPE: Type = struct {}, ENTITY_ALIAS := "Entity");
Entity_Manager :: struct($HEADER_TYPE: Type) {
    items: [..]Raw_Entity(HEADER_TYPE);
    freelist: [..]Entity_Handle;
    count: u32;
}
#assert (is_constant(ENTITY_HEADER_TYPE));

#add_context entities: *Entity_Manager(ENTITY_HEADER_TYPE);

Entity_Handle :: struct {
    index: u32;
    generation: u32;
}

// #insert "Cool_Man :s32:4;" :: ;
// #insert ENTITY_ALIAS :: Raw_Entity(ENTITY_HEADER_TYPE);;
#insert #run alias_string();

alias_string :: () -> string {
    return sprint("% :: Raw_Entity(ENTITY_HEADER_TYPE);", ENTITY_ALIAS);
}

NULL_HANDLE :: Entity_Handle.{};

operator == :: (a: Entity_Handle, b: Entity_Handle) -> bool {
    return a.index == b.index && a.generation == b.generation;
}

handle_compare :: (a: Entity_Handle, b: Entity_Handle) -> bool {
    return a.index == b.index && a.generation == b.generation;
}

handle_hash :: (a: Entity_Handle) -> u32 {return sdbm_hash(*a, size_of(Entity_Handle));}

Raw_Entity :: struct($HEADER_TYPE: Type) {
    #as using header: HEADER_TYPE;
    using footer: Entity_Footer;
}

Entity_Footer :: struct {
    handle: Entity_Handle;
    parent: Entity_Handle;
    first_child: Entity_Handle;
    last_child: Entity_Handle;
    prev_sibling: Entity_Handle;
    next_sibling: Entity_Handle;
}

entities_clear :: (e: *Entity_Manager = context.entities) {
    should_init();
    array_reset_keeping_memory(*e.items);
    array_reset_keeping_memory(*e.freelist);
}

entities_free :: (e: *Entity_Manager = context.entities) {
    should_init();
    array_free(e.items);
    array_free(e.freelist);
}

entity_add :: (new_entity: Raw_Entity(ENTITY_HEADER_TYPE), e: *Entity_Manager = context.entities) -> Entity_Handle {
    should_init();
    entity := new_entity;
    if e.freelist.count > 0 {
        handle := pop(*e.freelist);
        handle.generation += 1;
        entity.handle = handle;
        e.items[handle.index] = entity;
        e.count += 1;
        return entity.handle;
    }

    if e.items.count == 0 {
        array_add(*e.items, Raw_Entity(ENTITY_HEADER_TYPE).{});
    }

    index := cast(u32)e.items.count;
    entity.handle.index = index;
    entity.handle.generation = 1;
    array_add(*e.items, entity);
    e.count += 1;
    return entity.handle;
}

entity_get :: (handle: Entity_Handle, e: *Entity_Manager = context.entities) -> *Raw_Entity(ENTITY_HEADER_TYPE) {
    should_init();
    if handle.index > 0 && cast(int)handle.index < e.items.count && e.items[handle.index].handle == handle {
        return *e.items[handle.index];
    }
    return null;
}

entity_remove :: (handle: Entity_Handle, e: *Entity_Manager = context.entities, depth := 0) {
    should_init();
    if handle.index > 0 && cast(int)handle.index < e.items.count && e.items[handle.index].handle == handle {
        entity := entity_get(handle);
        if entity_valid(entity.first_child) {
            current_child := entity_get(entity.first_child);

            while entity_valid(current_child.next_sibling) {
                entity_remove(current_child.next_sibling, depth = depth + 1);
            }

            entity_remove(entity.first_child, depth = depth + 1);
        }

        if entity_valid(entity.next_sibling) {
            next_sibling := entity_get(entity.next_sibling);
            next_sibling.prev_sibling = entity.prev_sibling;
        }

        if entity_valid(entity.prev_sibling) {
            prev_sibling := entity_get(entity.prev_sibling);
            prev_sibling.next_sibling = entity.next_sibling;
        }

        if !entity_valid(entity.prev_sibling) && entity_valid(entity.parent) {
            parent := entity_get(entity.parent);
            parent.first_child = entity.next_sibling;
        }

        array_add(*e.freelist, handle);
        e.items[handle.index] = .{};
        e.count -= 1;
    }
}

entity_valid :: (handle: Entity_Handle, e: *Entity_Manager = context.entities) -> bool {
    should_init();
    return entity_get(handle, e) != null;
}

entity_add_child :: (parent_handle: Entity_Handle, child_entity: Raw_Entity(ENTITY_HEADER_TYPE), e: *Entity_Manager = context.entities) -> Entity_Handle {
    should_init();
    child_handle: Entity_Handle;
    // check if parent is still valid
    if entity_valid(parent_handle) {
        child_handle = entity_add(child_entity);
        if !entity_valid(child_handle) {
            return child_handle;
        }

        parent_ptr := entity_get(parent_handle);
        child_ptr := entity_get(child_handle);
        child_ptr.parent = parent_handle;

        // you can also keep a handle to the last child to avoid iterating the list when inserting
        // assert((parent_ptr.first_child == NULL_HANDLE && parent_ptr.last_child == NULL_HANDLE) ||
        //        (parent_ptr.first_child != NULL_HANDLE && parent_ptr.last_child != NULL_HANDLE));

        child_ptr.prev_sibling = parent_ptr.last_child;
        if !entity_valid(parent_ptr.last_child) {
            parent_ptr.first_child = child_handle;
            parent_ptr.last_child = child_handle;
        } else {
            prev_sibling := entity_get(parent_ptr.last_child);
            prev_sibling.next_sibling = child_handle;
            parent_ptr.last_child = child_handle;
        }
    }
    return child_handle;
}

for_expansion :: (e: *Entity_Manager, body: Code, flags: For_Flags) #expand {
    for index: 0..e.items.count - 1 {
        if index == 0 continue;
        if e.items[index].handle.index == 0 continue;

        `it := *e.items[index];
        `it_index := index;
        #insert body;
    }
}

should_init :: () #expand {
    print("Entities Initialized\n");
    if !context.entities {
        context.entities = New(Entity_Manager(ENTITY_HEADER_TYPE));
        `e = context.entities;
    }
}

#import "Basic";
