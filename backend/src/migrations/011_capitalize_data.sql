UPDATE products 
SET 
  name = INITCAP(name),
  category = INITCAP(category),
  color = INITCAP(color);

UPDATE categories
SET name = INITCAP(name);
