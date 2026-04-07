-- =============================================================================
-- CrisisConnect - AlloyDB Schema Setup
-- Run this in AlloyDB Studio after cluster/instance are ready
-- =============================================================================

-- Step 1: Enable Extensions
CREATE EXTENSION IF NOT EXISTS google_ml_integration CASCADE;
CREATE EXTENSION IF NOT EXISTS vector CASCADE;

-- Step 2: Grant embedding permission
GRANT EXECUTE ON FUNCTION embedding TO postgres;

-- Step 3: Register Gemini 3 Flash model (REPLACE YOUR_PROJECT_ID!)
CALL google_ml.create_model(
    model_id => 'gemini-3-flash-preview',
    model_request_url => 'https://aiplatform.googleapis.com/v1/projects/YOUR_PROJECT_ID/locations/global/publishers/google/models/gemini-3-flash-preview:generateContent',
    model_qualified_name => 'gemini-3-flash-preview',
    model_provider => 'google',
    model_type => 'llm',
    model_auth_type => 'alloydb_service_agent_iam'
);

-- =============================================================================
-- TABLE 1: community_resources (Track 3 - Vector Search)
-- =============================================================================
CREATE TABLE IF NOT EXISTS community_resources (
    resource_id       SERIAL PRIMARY KEY,
    resource_type     VARCHAR(50) NOT NULL,
    description       TEXT NOT NULL,
    quantity          NUMERIC,
    unit              VARCHAR(30),
    owner_name        VARCHAR(100) NOT NULL,
    contact_phone     VARCHAR(20),
    address           TEXT,
    available         BOOLEAN DEFAULT true,
    listed_date       TIMESTAMP DEFAULT NOW(),
    description_embedding VECTOR(768)
);

-- =============================================================================
-- TABLE 2: volunteers (Track 3 - Vector Search)
-- =============================================================================
CREATE TABLE IF NOT EXISTS volunteers (
    volunteer_id        SERIAL PRIMARY KEY,
    name                VARCHAR(100) NOT NULL,
    skills              TEXT NOT NULL,
    contact_phone       VARCHAR(20),
    location            VARCHAR(200),
    availability_status VARCHAR(20) DEFAULT 'available',
    registered_date     TIMESTAMP DEFAULT NOW(),
    skills_embedding    VECTOR(768)
);

-- =============================================================================
-- TABLE 3: emergency_tasks (Track 3 - ai.if() Vibe Check)
-- =============================================================================
CREATE TABLE IF NOT EXISTS emergency_tasks (
    task_id          SERIAL PRIMARY KEY,
    task_description TEXT NOT NULL,
    priority         INTEGER NOT NULL,
    category         VARCHAR(50),
    crisis_type      VARCHAR(50),
    phase            VARCHAR(20)
);

-- =============================================================================
-- VECTOR INDEXES (for faster cosine distance search)
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_resources_embedding ON community_resources
    USING ivfflat (description_embedding vector_cosine_ops) WITH (lists = 5);

CREATE INDEX IF NOT EXISTS idx_volunteers_embedding ON volunteers
    USING ivfflat (skills_embedding vector_cosine_ops) WITH (lists = 5);

-- =============================================================================
-- SEED DATA: Community Resources (20 entries with in-database embeddings)
-- =============================================================================
INSERT INTO community_resources (resource_type, description, quantity, unit, owner_name, contact_phone, address, available, description_embedding) VALUES
-- WATER
('water', 'Clean drinking water - 10 gallon jugs, purified and sealed', 10, 'gallons', 'Maria Santos', '+63-917-123-4567', '123 Rizal St, Quezon City, Manila', true, embedding('text-embedding-005', 'Clean drinking water - 10 gallon jugs, purified and sealed')::vector),
('water', 'Portable water purification tablets, 200 count, treats up to 200 liters', 200, 'tablets', 'Akiko Yamamoto', '+81-90-2222-3333', '5-1 Kanda, Chiyoda, Tokyo', true, embedding('text-embedding-005', 'Portable water purification tablets, 200 count, treats up to 200 liters')::vector),
('water', 'Water storage containers 20L capacity, food grade, brand new sealed', 5, 'containers', 'Suresh Kumar', '+91-98765-55555', '12 Marine Drive, Mumbai', true, embedding('text-embedding-005', 'Water storage containers 20L capacity, food grade, brand new sealed')::vector),
-- FOOD
('food', 'Canned goods assortment - beans, tuna, vegetables, enough for family of 4 for 3 days', 24, 'cans', 'Raj Patel', '+91-98765-43210', '45 MG Road, Andheri, Mumbai', true, embedding('text-embedding-005', 'Canned goods assortment - beans, tuna, vegetables, enough for family of 4 for 3 days')::vector),
('food', 'Rice 25kg bag, sealed and dry, long grain jasmine rice', 2, 'bags', 'Lito Reyes', '+63-917-555-6666', '78 Tomas Morato, Quezon City, Manila', true, embedding('text-embedding-005', 'Rice 25kg bag, sealed and dry, long grain jasmine rice')::vector),
('food', 'Baby formula and infant food jars, various flavors, unexpired', 12, 'jars', 'Priya Mehta', '+91-98765-77777', '90 Hill Road, Bandra, Mumbai', true, embedding('text-embedding-005', 'Baby formula and infant food jars, various flavors, unexpired')::vector),
-- MEDICAL
('medical', 'First aid kit with bandages, antiseptic, pain relievers, basic medications', 3, 'kits', 'Yuki Tanaka', '+81-90-1234-5678', '2-3-1 Shibuya, Tokyo', true, embedding('text-embedding-005', 'First aid kit with bandages, antiseptic, pain relievers, basic medications')::vector),
('medical', 'Prescription insulin, refrigerated, Type 1 diabetes supply for 2 weeks', 14, 'doses', 'Dr. Ramos', '+63-917-888-9999', 'Manila Doctors Hospital, Ermita, Manila', true, embedding('text-embedding-005', 'Prescription insulin, refrigerated, Type 1 diabetes supply for 2 weeks')::vector),
('medical', 'Oxygen concentrator portable, battery backup, 5L/min capacity', 1, 'unit', 'Haruki Sato', '+81-90-4444-5555', '3-8 Roppongi, Minato, Tokyo', true, embedding('text-embedding-005', 'Oxygen concentrator portable, battery backup, 5L/min capacity')::vector),
-- SHELTER
('shelter', 'Spare bedroom for displaced family, can host 4 people, ground floor access', 1, 'room', 'Chen Wei', '+86-138-0000-1234', '88 Nanjing Road, Shanghai', true, embedding('text-embedding-005', 'Spare bedroom for displaced family, can host 4 people, ground floor access')::vector),
('shelter', 'Community hall available as temporary shelter, capacity 50 people, has kitchen', 1, 'hall', 'Barangay Malabon', '+63-2-8888-1111', 'Barangay Hall, Malabon, Manila', true, embedding('text-embedding-005', 'Community hall available as temporary shelter, capacity 50 people, has kitchen')::vector),
('shelter', 'Two-person camping tent, waterproof, easy setup, good for temporary shelter', 3, 'tents', 'James O Brien', '+61-4-1234-5678', '22 Flinders St, Townsville, QLD', true, embedding('text-embedding-005', 'Two-person camping tent, waterproof, easy setup, good for temporary shelter')::vector),
-- TOOLS
('tools', 'Chainsaw and hand tools for debris clearing, work gloves and safety goggles', 1, 'set', 'Bong dela Cruz', '+63-917-111-2222', '56 Aurora Blvd, Quezon City, Manila', true, embedding('text-embedding-005', 'Chainsaw and hand tools for debris clearing, work gloves and safety goggles')::vector),
('tools', 'Rope 50 meters heavy duty, rated for 500kg, suitable for rescue operations', 3, 'coils', 'Takeshi Honda', '+81-90-6666-7777', '1-1 Marunouchi, Chiyoda, Tokyo', true, embedding('text-embedding-005', 'Rope 50 meters heavy duty, rated for 500kg, suitable for rescue operations')::vector),
('tools', 'Sandbags 200 count, empty, with sand available nearby for flood barrier', 200, 'bags', 'Anwar Hassan', '+880-171-000-1234', '15 Dhanmondi, Dhaka', true, embedding('text-embedding-005', 'Sandbags 200 count, empty, with sand available nearby for flood barrier')::vector),
-- POWER
('power', 'Portable gasoline generator 3000W with 5 gallons fuel', 1, 'unit', 'Arjun Mehta', '+91-98765-11111', '78 Linking Road, Bandra, Mumbai', true, embedding('text-embedding-005', 'Portable gasoline generator 3000W with 5 gallons fuel')::vector),
('power', 'Solar panel portable 200W with battery pack, can charge phones and devices', 2, 'units', 'Jun Park', '+82-10-1234-5678', '123 Gangnam-daero, Seoul', true, embedding('text-embedding-005', 'Solar panel portable 200W with battery pack, can charge phones and devices')::vector),
-- COMMUNICATION
('communication', 'Satellite phone with prepaid minutes, works without cell towers', 1, 'phone', 'Sarah Tan', '+65-9123-4567', '10 Orchard Road, Singapore', true, embedding('text-embedding-005', 'Satellite phone with prepaid minutes, works without cell towers')::vector),
('communication', 'Battery powered AM/FM radio with emergency weather band and flashlight', 4, 'units', 'Anh Nguyen', '+84-90-123-4567', '35 Le Loi, District 1, Ho Chi Minh City', true, embedding('text-embedding-005', 'Battery powered AM/FM radio with emergency weather band and flashlight')::vector),
-- TRANSPORT
('transport', 'Inflatable rescue boat, 4-person capacity with oars and hand pump', 1, 'boat', 'Diego Santos', '+63-917-222-3333', '44 Roxas Blvd, Manila', true, embedding('text-embedding-005', 'Inflatable rescue boat, 4-person capacity with oars and hand pump')::vector);


-- =============================================================================
-- SEED DATA: Volunteers (15 entries with skill embeddings)
-- =============================================================================
INSERT INTO volunteers (name, skills, contact_phone, location, availability_status, skills_embedding) VALUES
('Dr. Anika Sharma', 'Emergency medicine, trauma care, triage, CPR certified instructor', '+91-98765-22222', 'Mumbai, India', 'available', embedding('text-embedding-005', 'Emergency medicine, trauma care, triage, CPR certified instructor')::vector),
('Kenji Watanabe', 'Search and rescue certified, structural assessment, heavy equipment operation', '+81-90-5555-6666', 'Tokyo, Japan', 'available', embedding('text-embedding-005', 'Search and rescue certified, structural assessment, heavy equipment operation')::vector),
('Rosa Gonzales', 'Community organizing, Tagalog-English translation, child care, food distribution', '+63-917-333-4444', 'Manila, Philippines', 'available', embedding('text-embedding-005', 'Community organizing, Tagalog-English translation, child care, food distribution')::vector),
('Marcus Chen', 'Ham radio operator, emergency communications, network setup and repair', '+61-4-5555-6666', 'Sydney, Australia', 'available', embedding('text-embedding-005', 'Ham radio operator, emergency communications, network setup and repair')::vector),
('Fatima Rahman', 'Nurse practitioner, wound care, pediatric care, Bengali-English-Hindi trilingual', '+880-171-555-6666', 'Dhaka, Bangladesh', 'available', embedding('text-embedding-005', 'Nurse practitioner, wound care, pediatric care, Bengali-English-Hindi trilingual')::vector),
('Taro Kimura', 'Civil engineer, building damage assessment, earthquake safety specialist', '+81-90-7777-8888', 'Tokyo, Japan', 'available', embedding('text-embedding-005', 'Civil engineer, building damage assessment, earthquake safety specialist')::vector),
('Elena Cruz', 'Red Cross trained, emergency shelter management, logistics coordination', '+63-917-444-5555', 'Quezon City, Philippines', 'available', embedding('text-embedding-005', 'Red Cross trained, emergency shelter management, logistics coordination')::vector),
('David Kumar', 'Drone pilot certified, aerial survey, mapping, photography for damage assessment', '+91-98765-88888', 'Mumbai, India', 'available', embedding('text-embedding-005', 'Drone pilot certified, aerial survey, mapping, photography for damage assessment')::vector),
('Mei-Ling Wu', 'Psychological first aid, crisis counseling, grief support, Mandarin-English bilingual', '+886-9-1234-5678', 'Taipei, Taiwan', 'available', embedding('text-embedding-005', 'Psychological first aid, crisis counseling, grief support, Mandarin-English bilingual')::vector),
('Ahmed Al-Farsi', 'Water purification specialist, sanitation engineering, disease prevention', '+65-9876-5432', 'Singapore', 'available', embedding('text-embedding-005', 'Water purification specialist, sanitation engineering, disease prevention')::vector),
('Nguyen Thi Lan', 'Boat operator, water rescue, swimming instructor, flood evacuation specialist', '+84-90-888-9999', 'Hanoi, Vietnam', 'available', embedding('text-embedding-005', 'Boat operator, water rescue, swimming instructor, flood evacuation specialist')::vector),
('Jessica Lim', 'Social media crisis communication, information verification, rumor tracking', '+65-8888-7777', 'Singapore', 'available', embedding('text-embedding-005', 'Social media crisis communication, information verification, rumor tracking')::vector),
('Ravi Shankar', 'Generator repair, electrical work, solar panel installation and maintenance', '+91-98765-99999', 'Mumbai, India', 'available', embedding('text-embedding-005', 'Generator repair, electrical work, solar panel installation and maintenance')::vector),
('Yuko Abe', 'Elderly care specialist, mobility assistance, Japanese Sign Language interpreter', '+81-90-9999-0000', 'Ishikawa, Japan', 'available', embedding('text-embedding-005', 'Elderly care specialist, mobility assistance, Japanese Sign Language interpreter')::vector),
('Paulo Santos', 'Construction worker, debris clearing, temporary structure building, carpentry', '+63-917-666-7777', 'Manila, Philippines', 'available', embedding('text-embedding-005', 'Construction worker, debris clearing, temporary structure building, carpentry')::vector);


-- =============================================================================
-- SEED DATA: Emergency Tasks (30+ entries for ai.if() filtering)
-- =============================================================================
INSERT INTO emergency_tasks (task_description, priority, category, crisis_type, phase) VALUES
-- TYPHOON tasks
('Board up windows and secure loose outdoor objects that could become projectiles', 1, 'safety', 'typhoon', 'before'),
('Fill bathtub and containers with clean water before supply is disrupted', 1, 'supplies', 'typhoon', 'before'),
('Charge all phones, power banks, and flashlights to full capacity', 1, 'communication', 'typhoon', 'before'),
('Move to the innermost room away from windows during peak winds', 1, 'safety', 'typhoon', 'during'),
('Do NOT go outside during the eye of the storm - winds will resume from opposite direction', 1, 'safety', 'typhoon', 'during'),
('Check on elderly neighbors and families with young children after storm passes', 2, 'community', 'typhoon', 'after'),
('Document damage with photos for insurance claims before cleanup', 2, 'recovery', 'typhoon', 'after'),
('Avoid downed power lines and standing water which may be electrified', 1, 'safety', 'typhoon', 'after'),
-- EARTHQUAKE tasks
('DROP, COVER, and HOLD ON - get under sturdy furniture immediately', 1, 'safety', 'earthquake', 'during'),
('Do NOT run outside during shaking - falling debris is the biggest danger', 1, 'safety', 'earthquake', 'during'),
('After shaking stops, check for gas leaks - if you smell gas, open windows and leave', 1, 'safety', 'earthquake', 'after'),
('Check building for structural damage - cracks in walls, tilting, foundation issues', 2, 'safety', 'earthquake', 'after'),
('Be prepared for aftershocks - they can be nearly as strong as the main quake', 2, 'safety', 'earthquake', 'after'),
('Do NOT re-enter damaged buildings until cleared by structural engineer', 1, 'safety', 'earthquake', 'after'),
-- FLOOD tasks
('Move important documents and electronics to the highest floor', 1, 'supplies', 'flood', 'before'),
('Turn off electricity at the main breaker if water is rising', 1, 'safety', 'flood', 'during'),
('Never walk or drive through flood water - 6 inches can knock you down', 1, 'safety', 'flood', 'during'),
('Stack sandbags around entry points if water is approaching your home', 2, 'safety', 'flood', 'before'),
('After water recedes, do NOT drink tap water until authorities confirm it is safe', 1, 'supplies', 'flood', 'after'),
('Beware of snakes and insects displaced by flooding - check shoes and clothing', 2, 'safety', 'flood', 'after'),
-- TSUNAMI tasks
('If near coast and feel strong earthquake, move to high ground IMMEDIATELY', 1, 'safety', 'tsunami', 'during'),
('Do NOT wait for official warning - natural signs (earthquake, ocean receding) mean GO NOW', 1, 'safety', 'tsunami', 'during'),
('Move at least 2km inland or 30 meters above sea level', 1, 'safety', 'tsunami', 'during'),
('Do NOT return to coast until authorities give all-clear - multiple waves can arrive hours apart', 1, 'safety', 'tsunami', 'after'),
-- GENERAL tasks (apply to all crises)
('Prepare a go-bag with 72 hours of essentials: water, food, medications, documents, cash', 1, 'supplies', 'general', 'before'),
('Establish a family meeting point and communication plan', 2, 'communication', 'general', 'before'),
('Keep emergency radio tuned to local disaster frequency for official updates', 2, 'communication', 'general', 'during'),
('Register with local disaster relief agency for assistance', 3, 'recovery', 'general', 'after'),
('Check on neighbors especially elderly, disabled, and families with young children', 2, 'community', 'general', 'after'),
('Boil water before drinking if water supply may be contaminated', 1, 'supplies', 'general', 'after'),
-- WILDFIRE tasks
('Create defensible space - clear dry brush 30 meters around your home', 2, 'safety', 'wildfire', 'before'),
('Close all windows and doors, remove flammable curtains', 1, 'safety', 'wildfire', 'during'),
('If evacuation ordered, leave IMMEDIATELY - do not wait to see the fire', 1, 'safety', 'wildfire', 'during'),
-- CYCLONE tasks
('Secure or bring inside all outdoor furniture and loose items', 1, 'safety', 'cyclone', 'before'),
('Stay away from windows and doors during the cyclone', 1, 'safety', 'cyclone', 'during'),
('Watch for storm surge flooding if near the coast', 1, 'safety', 'cyclone', 'during');


-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================

-- Test vector search
-- SELECT resource_id, description, 1 - (description_embedding <=> embedding('text-embedding-005', 'drinking water')::vector) as score
-- FROM community_resources WHERE available = true ORDER BY score DESC LIMIT 3;

-- Test ai.if()
-- SELECT task_id, task_description, priority
-- FROM emergency_tasks
-- WHERE crisis_type = 'typhoon'
--   AND ai.if(
--     prompt => 'Is this task relevant for: "typhoon approaching Manila, family with baby needs to prepare"? Task: "' || task_description || '"',
--     model_id => 'gemini-3-flash-preview'
--   )
-- ORDER BY priority;
