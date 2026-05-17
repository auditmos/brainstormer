// rule_id: effects/sharing-logic-between-handlers
import { useEffect, useState } from 'react';

interface Product {
  id: string;
  name: string;
}

interface Cart {
  justAddedId: string | null;
  itemIds: string[];
}

function addToCart(cart: Cart, product: Product): Cart {
  return { justAddedId: product.id, itemIds: [...cart.itemIds, product.id] };
}

function showNotification(_msg: string): void {}
function navigate(_path: string): void {}

interface ProductPageProps {
  product: Product;
}

export function ProductPage({ product }: ProductPageProps) {
  const [cart, setCart] = useState<Cart>({ justAddedId: null, itemIds: [] });

  useEffect(() => {
    if (cart.justAddedId === product.id) {
      showNotification(`Added ${product.name} to cart!`);
    }
  }, [cart, product]);

  function handleBuy() {
    setCart(addToCart(cart, product));
  }

  function handleCheckout() {
    setCart(addToCart(cart, product));
    navigate('/checkout');
  }

  return (
    <div>
      <button onClick={handleBuy}>Buy</button>
      <button onClick={handleCheckout}>Checkout</button>
    </div>
  );
}
