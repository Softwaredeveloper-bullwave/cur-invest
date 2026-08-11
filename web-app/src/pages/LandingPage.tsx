import { Navbar } from '../components/layout/Navbar'
import { Footer } from '../components/layout/Footer'
import {
  HeroSection,
  WhySection,
  ProductsSection,
  ToolsSection,
  ProFeaturesSection,
  TrendingSection,
  TestimonialsSection,
  FaqSection,
  CtaSection,
} from '../components/marketing/Sections'

export function LandingPage() {
  return (
    <>
      <Navbar />
      <main>
        <HeroSection />
        <WhySection />
        <ProductsSection />
        <ToolsSection />
        <ProFeaturesSection />
        <TrendingSection />
        <TestimonialsSection />
        <FaqSection />
        <CtaSection />
      </main>
      <Footer />
    </>
  )
}
